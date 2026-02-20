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

    final pendingIncidents = await _localDatabase.getPendingIncidents();

    for (final incident in pendingIncidents) {
      try {
        await _syncIncident(incident);
      } on Exception catch (e) {
        debugPrint('Error syncing incident ${incident['id']}: $e');
        // Optionally update status to 'error' (2)
        await _localDatabase.updateIncidentSyncStatus(
          incident['id'] as String,
          2,
        );
      }
    }
  }

  Future<void> _syncIncident(Map<String, dynamic> incident) async {
    final incidentId = incident['id'] as String;

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

    // 2. Insert/Upsert Incident to Supabase
    // Map local fields to Supabase Table fields
    // Local: id, title, description, priority, status, project_id,
    // category, location_tag, gps_lat, gps_lng
    // Online: id, project_id, ... (from 01-tables.sql)

    // Handle GPS Point (Skipping complex GeoJSON for now)

    final incidentData = {
      'id': incidentId,
      'project_id':
          incident['project_id'], // Must be valid UUID of existing project
      'title': incident['title'],
      'description': incident['description'],
      'priority': incident['priority'],
      'status': incident['status'],
      'category': incident['category'], // Trade
      'location_tag': incident['location_tag'], // Specific location
      'audio_url': audioUrl,
      'created_at': incident['created_at'],
      'created_by': _supabaseClient.auth.currentUser?.id,
      // 'gps_coords': ... // Skipping complex GeoJSON for now
    };

    // Remove nulls to avoid overwriting with null if upserting?
    // Or keep them.

    await _supabaseClient.from('incidents').upsert(incidentData);

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

        // Update local photo sync status
        // We need a method in LocalDatabase to update photo sync status
        // For now, assume we implement it or add sql execution
        // await _localDatabase.updatePhotoSyncStatus(...)
      }
    }

    // 4. Mark Incident as Synced
    await _localDatabase.updateIncidentSyncStatus(incidentId, 1);
  }
}
