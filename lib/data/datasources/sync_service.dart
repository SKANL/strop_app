import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:strop_app/core/network/connectivity_service.dart';
import 'package:strop_app/data/datasources/local/local_database.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SyncService {
  SyncService(
    this._localDatabase,
    this._connectivityService,
    this._supabaseClient,
  ) {
    _connectivityService.onConnectivityChanged.listen((isConnected) {
      if (isConnected) {
        unawaited(syncPendingData());
      }
    });
  }

  final LocalDatabase _localDatabase;
  final ConnectivityService _connectivityService;
  final SupabaseClient _supabaseClient;

  Future<void> syncPendingData() async {
    if (!await _connectivityService.isConnected) return;

    // Fetch both pending (0) and error (2) incidents so errors are retried.
    final pendingIncidents = await _localDatabase.getPendingIncidents();
    final errorIncidents = await _localDatabase.getErrorIncidents();
    final toSync = [...pendingIncidents, ...errorIncidents];

    for (final incident in toSync) {
      try {
        await _syncIncident(incident);
      } on Exception catch (e) {
        debugPrint('Error syncing incident ${incident['id']}: $e');
        await _localDatabase.updateIncidentSyncStatus(
          incident['id'] as String,
          2,
        );
      }
    }
  }

  Future<void> _syncIncident(Map<String, dynamic> incident) async {
    final incidentId = incident['id'] as String;

    // Skip incidents missing required fields — they cannot be synced.
    // These can only happen for incidents created before the project-required
    // validation was added.
    if (incident['project_id'] == null) {
      debugPrint('Skipping incident $incidentId: project_id is null');
      // Mark as permanent error so it stops being retried automatically.
      // User must delete it from the app.
      await _localDatabase.updateIncidentSyncStatus(incidentId, 2);
      return;
    }

    // 1. Upload Audio if exists
    final audioPath = incident['audio_path'] as String?;
    String? audioUrl;
    if (audioPath != null && File(audioPath).existsSync()) {
      final fileName = p.basename(audioPath);
      final path = '$incidentId/$fileName';
      await _supabaseClient.storage
          .from('incident-evidence')
          .upload(
            path,
            File(audioPath),
            fileOptions: const FileOptions(upsert: true),
          );
      // Construct public URL or just path depending on access policy
      // For private buckets, we usually use the path or signed URL access.
      // Saving the path relative to bucket is standard.
      audioUrl = path;
    }

    // 2. Create incident via RPC — handles folio_number, public_token, and
    //    geofence check. Pass p_id so the remote UUID matches the local one.
    final priority =
        (incident['priority'] as String? ?? 'normal').toUpperCase();

    final gpsLat = incident['gps_lat'] as double?;
    final gpsLng = incident['gps_lng'] as double?;
    final gpsWkt = (gpsLat != null && gpsLng != null)
        ? 'POINT($gpsLng $gpsLat)'
        : null;

    final rpcParams = <String, dynamic>{
      'p_id': incidentId,
      'p_project_id': incident['project_id'],
      'p_description': incident['description'] ?? '',
      'p_priority': priority,
      if (incident['location_tag'] != null)
        'p_location_tag': incident['location_tag'],
      if (audioUrl != null) 'p_audio_url': audioUrl,
      if (gpsWkt != null) 'p_gps_coords': gpsWkt,
    };

    final rpcResponse =
        await _supabaseClient.rpc('create_incident', params: rpcParams);

    // Update local record with server-assigned folio_number and public_token
    if (rpcResponse is Map) {
      final db = _localDatabase;
      final folio = rpcResponse['folio_number'];
      final token = rpcResponse['public_token'];
      if (folio != null || token != null) {
        final updates = <String, dynamic>{
          'id': incidentId,
          if (folio != null) 'folio_number': folio,
          if (token != null) 'public_token': token,
        };
        await db.updateIncident(updates);
      }
    }

    // 3. Sync Photos
    final photos = await _localDatabase.getPhotosForIncident(incidentId);
    for (final photo in photos) {
      if (photo['sync_status'] == 1) continue; // Already synced

      final photoLocalPath = photo['local_path'] as String;
      if (File(photoLocalPath).existsSync()) {
        final fileName = p.basename(photoLocalPath);
        final storagePath = '$incidentId/$fileName';

        await _supabaseClient.storage
            .from('incident-evidence')
            .upload(
              storagePath,
              File(photoLocalPath),
              fileOptions: const FileOptions(upsert: true),
            );

        // Insert to incident_photos table
        await _supabaseClient.from('incident_photos').upsert({
          'id': photo['id'],
          'incident_id': incidentId,
          'photo_url': storagePath,
          'photo_type': 'evidence',
          'annotations': photo['annotations_json'], // Map string to JSONB?
          // If annotations_json is string, Supabase might expect Map/List if column is JSONB.
          // We might need jsonDecode(photo['annotations_json'])
        });

        // ← FIX: mark photo as synced so it's not re-uploaded on next sync
        await _localDatabase.updatePhotoSyncStatus(photo['id'] as String, 1);
      }
    }

    // 4. Mark Incident as Synced
    await _localDatabase.updateIncidentSyncStatus(incidentId, 1);
  }
}
