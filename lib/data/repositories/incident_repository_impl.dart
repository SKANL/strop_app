import 'dart:async';
import 'package:strop_app/data/datasources/local/local_database.dart';
import 'package:strop_app/data/datasources/sync_service.dart';
import 'package:strop_app/domain/entities/incident.dart';
import 'package:strop_app/domain/repositories/incident_repository.dart';

class IncidentRepositoryImpl implements IncidentRepository {
  IncidentRepositoryImpl(this._localDatabase, this._syncService) {
    unawaited(_refreshIncidents());
  }

  final LocalDatabase _localDatabase;
  final SyncService _syncService;

  final _incidentsController = StreamController<List<Incident>>.broadcast();

  Future<void> _refreshIncidents() async {
    final data = await _localDatabase.getAllIncidents();
    final incidents = <Incident>[];
    for (final map in data) {
      final photosData = await _localDatabase.getPhotosForIncident(
        map['id'] as String,
      );
      final photos = photosData.map((p) => p['local_path'] as String).toList();

      incidents.add(
        Incident(
          id: map['id'] as String,
          title: map['title'] as String? ?? 'Untitled',
          description: map['description'] as String?,
          location:
              map['project_id'] as String? ??
              'Unknown Project', // Mapping project_id to location for now
          specificLocation: map['location_tag'] as String?,
          createdAt: DateTime.parse(map['created_at'] as String),
          status: _parseStatus(map['status'] as String?),
          priority: _parsePriority(map['priority'] as String?),
          syncStatus: _parseSyncStatus(map['sync_status'] as int),
          photos: photos,
          audioPath: map['audio_path'] as String?,
          assignedTrade: _parseTrade(map['category'] as String?),
        ),
      );
    }
    _incidentsController.add(incidents);
  }

  @override
  Future<void> createIncident(Incident incident) async {
    // 1. Save to Local DB
    final incidentMap = {
      'id': incident.id,
      'title': incident.title,
      'description': incident.description,
      'priority': incident.priority.name.toUpperCase(),
      'status': incident.status.name.toUpperCase(),
      'project_id':
          incident.location, // Assuming location holds project_id for now
      'category': incident.assignedTrade?.name,
      'location_tag': incident.specificLocation,
      'audio_path': incident.audioPath,
      'created_by': 'CURRENT_USER_ID', // TODO(user): Get from AuthRepository
      'created_at': incident.createdAt.toIso8601String(),
      'sync_status': 0, // Pending
    };

    await _localDatabase.insertIncident(incidentMap);

    for (final photoPath in incident.photos) {
      await _localDatabase.insertPhoto({
        'id':
            '${incident.id}_'
            '${DateTime.now().millisecondsSinceEpoch}', // Generate ID
        'incident_id': incident.id,
        'local_path': photoPath,
        'created_at': DateTime.now().toIso8601String(),
        'sync_status': 0,
      });
    }

    await _refreshIncidents();

    // 2. Trigger Sync (Fire and Forget)
    unawaited(_syncService.syncPendingData());
  }

  @override
  Future<List<Incident>> getIncidents() async {
    await _refreshIncidents();
    final data = await _localDatabase.getAllIncidents();
    return _mapDataToIncidents(data);
  }

  Future<List<Incident>> _mapDataToIncidents(
    List<Map<String, dynamic>> data,
  ) async {
    final incidents = <Incident>[];
    for (final map in data) {
      final photosData = await _localDatabase.getPhotosForIncident(
        map['id'] as String,
      );
      final photos = photosData.map((p) => p['local_path'] as String).toList();

      incidents.add(
        Incident(
          id: map['id'] as String,
          title: map['title'] as String? ?? 'Untitled',
          description: map['description'] as String?,
          location: map['project_id'] as String? ?? 'Unknown Project',
          specificLocation: map['location_tag'] as String?,
          createdAt: DateTime.parse(map['created_at'] as String),
          status: _parseStatus(map['status'] as String?),
          priority: _parsePriority(map['priority'] as String?),
          syncStatus: _parseSyncStatus(map['sync_status'] as int),
          photos: photos,
          audioPath: map['audio_path'] as String?,
          assignedTrade: _parseTrade(map['category'] as String?),
        ),
      );
    }
    return incidents;
  }

  @override
  Stream<List<Incident>> get incidentsStream => _incidentsController.stream;

  @override
  Future<void> syncPendingIncidents() async {
    await _syncService.syncPendingData();
    await _refreshIncidents();
  }

  @override
  Future<void> updateIncident(Incident incident) async {
    // Similar to create, but update
    // For now, implementing basic update
    // We need an update method in LocalDatabase?
    // insert uses ConflictAlgorithm.replace so it might work for basic fields.
    // However, replace might wipe out other fields if we don't provide them.
    // LocalDatabase insertIncident uses replace.
    // So distinct update might be safer if we only update partials.
    // But here we have full object.
    await createIncident(incident); // Re-use create for upsert if ID matches
  }

  @override
  Future<int> getPendingIncidentCount() async {
    final counts = await _localDatabase.getIncidentCounts();
    return counts['pending'] ?? 0;
  }

  // Helpers
  IncidentPriority _parsePriority(String? val) {
    if (val == 'URGENT') return IncidentPriority.urgent;
    if (val == 'CRITICAL') return IncidentPriority.critical;
    return IncidentPriority.normal;
  }

  IncidentStatus _parseStatus(String? val) {
    if (val == 'IN_REVIEW') return IncidentStatus.inReview;
    if (val == 'CLOSED') return IncidentStatus.done;
    return IncidentStatus.pending;
  }

  SyncStatus _parseSyncStatus(int? val) {
    if (val == 1) return SyncStatus.synced;
    if (val == 2) return SyncStatus.error;
    if (val == 3) return SyncStatus.syncing;
    return SyncStatus.pending;
  }

  Trade? _parseTrade(String? val) {
    if (val == null) return null;
    return Trade.values.firstWhere(
      (e) => e.name == val,
      orElse: () => Trade.other,
    );
  }
}
