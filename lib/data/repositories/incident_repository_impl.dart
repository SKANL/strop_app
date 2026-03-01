import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:strop_app/data/datasources/local/local_database.dart';
import 'package:strop_app/data/datasources/sync_service.dart';
import 'package:strop_app/domain/entities/incident.dart';
import 'package:strop_app/domain/repositories/incident_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class IncidentRepositoryImpl implements IncidentRepository {
  IncidentRepositoryImpl(
    this._localDatabase,
    this._syncService,
    this._supabaseClient,
  ) {
    unawaited(_initializeData());
  }

  final LocalDatabase _localDatabase;
  final SyncService _syncService;
  final SupabaseClient _supabaseClient;

  final _incidentsController = StreamController<List<Incident>>.broadcast();

  RealtimeChannel? _realtimeChannel;

  Future<void> _initializeData() async {
    // First show local data immediately
    await _refreshIncidents();
    // Then try to fetch from Supabase in background
    unawaited(fetchFromSupabase());
    // Start realtime subscription for live updates
    unawaited(_startRealtimeSubscription());
  }

  Future<void> _startRealtimeSubscription() async {
    final userId = _supabaseClient.auth.currentUser?.id;
    if (userId == null) return;

    _realtimeChannel = _supabaseClient
        .channel('incidents_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'incidents',
          callback: (payload) {
            debugPrint('Realtime incident update: ${payload.eventType}');
            unawaited(fetchFromSupabase());
          },
        )
        .subscribe();
  }

  void dispose() {
    _realtimeChannel?.unsubscribe();
    _incidentsController.close();
  }

  /// Downloads incidents from Supabase and upserts them into local SQLite.
  Future<void> fetchFromSupabase() async {
    final userId = _supabaseClient.auth.currentUser?.id;
    if (userId == null) return;

    try {
      // Fetch all incidents the current user is authorised to see (RLS handles
      // scoping). Staff see all org-project incidents; crew see their own.
      // Also join projects(name) for location display and users(full_name) for
      // the assigned_to display, falling back to UUID if no FK match.
      final response = await _supabaseClient
          .from('incidents')
          .select(
            'id, title, description, priority, status, project_id,'
            ' category, location_tag, audio_url, created_at, created_by,'
            ' estimated_cost, is_billable, assigned_to, rejection_reason,'
            ' public_token,'
            ' project:projects!project_id(name),'
            ' assigned_user:users!assigned_to(full_name)',
          )
          .order('created_at', ascending: false)
          .limit(200);

      final db = _localDatabase;

      for (final row in response as List<dynamic>) {
        final map = row as Map<String, dynamic>;

        // Resolve human-readable names from joins
        final projectMap = map['project'] as Map<String, dynamic>?;
        final assignedUserMap = map['assigned_user'] as Map<String, dynamic>?;
        final assignedToDisplay =
            assignedUserMap?['full_name'] as String? ?? map['assigned_to'] as String?;
        final projectName = projectMap?['name'] as String?;
        final locationDisplay =
            map['location_tag'] as String? ??
            projectName ??
            'Ubicación desconocida';

        await db.upsertIncident({
          'id': map['id'],
          'title': map['title'] ?? '',
          'description': map['description'] ?? '',
          'priority': (map['priority'] as String?)?.toLowerCase() ?? 'normal',
          'status': _remoteToLocalStatus(map['status'] as String? ?? 'OPEN'),
          'project_id': map['project_id'],
          'category': map['category'],
          'location_tag': locationDisplay,
          'audio_path': map['audio_url'],  // store remote URL as audio_path
          'created_at': map['created_at'],
          'created_by': map['created_by'],
          'assigned_to': assignedToDisplay,
          'public_token': map['public_token'],
          'rejection_reason': map['rejection_reason'],
          'sync_status': 1, // Already synced
        });
      }

      await _refreshIncidents();
    } on Exception catch (e) {
      debugPrint('fetchFromSupabase error: $e');
    }
  }

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
          title: map['title'] as String? ?? 'Sin título',
          description: map['description'] as String?,
          location: map['location_tag'] as String? ?? 'Ubicación desconocida',
          projectId: map['project_id'] as String?,
          specificLocation: map['location_tag'] as String?,
          createdAt: DateTime.parse(map['created_at'] as String),
          status: _parseStatus(map['status'] as String?),
          priority: _parsePriority(map['priority'] as String?),
          syncStatus: _parseSyncStatus(map['sync_status'] as int? ?? 0),
          photos: photos,
          audioPath: map['audio_path'] as String?,
          assignedTrade: _parseTrade(map['category'] as String?),
          isSynced: (map['sync_status'] as int? ?? 0) == 1,
          publicToken: map['public_token'] as String?,
          rejectionReason: map['rejection_reason'] as String?,
          assignedTo: map['assigned_to'] as String?,
        ),
      );
    }
    _incidentsController.add(incidents);
  }

  @override
  Future<void> createIncident(Incident incident) async {
    final currentUserId = _supabaseClient.auth.currentUser?.id ?? '';

    final incidentMap = {
      'id': incident.id,
      'title': incident.title,
      'description': incident.description,
      'priority': incident.priority.name.toUpperCase(),
      'status': 'open',
      'project_id': incident.projectId,
      'category': incident.assignedTrade?.name,
      'location_tag': incident.specificLocation,
      'audio_path': incident.audioPath,
      'created_by': currentUserId,
      'created_at': incident.createdAt.toIso8601String(),
      'sync_status': 0,
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

  @override
  Stream<List<Incident>> get incidentsStream => _incidentsController.stream;

  @override
  Future<void> syncPendingIncidents() async {
    await _syncService.syncPendingData();
    await fetchFromSupabase();
  }

  @override
  Future<void> updateIncident(Incident incident) async {
    await _localDatabase.updateIncident({
      'id': incident.id,
      'status': incident.status.name.toLowerCase(),
      if (incident.rejectionReason != null)
        'rejection_reason': incident.rejectionReason,
      if (incident.publicToken != null)
        'public_token': incident.publicToken,
      'sync_status': 0,
    });
    await _refreshIncidents();

    // Push status change to Supabase immediately (best-effort)
    final userId = _supabaseClient.auth.currentUser?.id;
    if (userId != null) {
      try {
        await _supabaseClient
            .from('incidents')
            .update({
              'status': _statusToDb(incident.status),
              if (incident.status == IncidentStatus.closed)
                'closed_at': DateTime.now().toIso8601String(),
              if (incident.rejectionReason != null)
                'rejection_reason': incident.rejectionReason,
            })
            .eq('id', incident.id)
            .eq('created_by', userId);
        // Mark as synced locally
        await _localDatabase.updateIncident({
          'id': incident.id,
          'sync_status': 1,
        });
        await _refreshIncidents();
      } catch (e) {
        debugPrint('Warning: Failed to sync status to Supabase: $e');
        // Don't throw — local update succeeded; SyncService will retry
        unawaited(_syncService.syncPendingData());
      }
    } else {
      unawaited(_syncService.syncPendingData());
    }
  }

  String _statusToDb(IncidentStatus status) => switch (status) {
    IncidentStatus.open => 'OPEN',
    IncidentStatus.inReview => 'IN_REVIEW',
    IncidentStatus.closed => 'CLOSED',
    IncidentStatus.rejected => 'REJECTED',
  };

  @override
  Future<void> deleteIncident(String incidentId) async {
    await _localDatabase.deleteIncident(incidentId);
    await _refreshIncidents();
  }

  @override
  Future<int> getPendingIncidentCount() async {
    final pending = await _localDatabase.getPendingIncidents();
    return pending.length;
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
          title: map['title'] as String? ?? 'Sin título',
          description: map['description'] as String?,
          location: map['location_tag'] as String? ?? 'Ubicación desconocida',
          projectId: map['project_id'] as String?,
          specificLocation: map['location_tag'] as String?,
          createdAt: DateTime.parse(map['created_at'] as String),
          status: _parseStatus(map['status'] as String?),
          priority: _parsePriority(map['priority'] as String?),
          syncStatus: _parseSyncStatus(map['sync_status'] as int? ?? 0),
          photos: photos,
          audioPath: map['audio_path'] as String?,
          assignedTrade: _parseTrade(map['category'] as String?),
          isSynced: (map['sync_status'] as int? ?? 0) == 1,
          assignedTo: map['assigned_to'] as String?,
          publicToken: map['public_token'] as String?,
          rejectionReason: map['rejection_reason'] as String?,
        ),
      );
    }
    return incidents;
  }

  IncidentStatus _parseStatus(String? status) {
    switch (status?.toUpperCase()) {
      case 'OPEN':
      case 'open':
      case 'PENDING':
      case 'pending':
        return IncidentStatus.open;
      case 'IN_REVIEW':
      case 'in_review':
      case 'INREVIEW':
      case 'inreview':
        return IncidentStatus.inReview;
      case 'CLOSED':
      case 'closed':
      case 'DONE':
      case 'done':
        return IncidentStatus.closed;
      case 'REJECTED':
      case 'rejected':
        return IncidentStatus.rejected;
      default:
        return IncidentStatus.open;
    }
  }

  String _remoteToLocalStatus(String remoteStatus) {
    switch (remoteStatus) {
      case 'OPEN':
        return 'open';
      case 'IN_REVIEW':
        return 'inReview';
      case 'CLOSED':
        return 'closed';
      case 'REJECTED':
        return 'rejected';
      default:
        return 'open';
    }
  }

  IncidentPriority _parsePriority(String? priority) {
    switch (priority?.toUpperCase()) {
      case 'URGENT':
        return IncidentPriority.urgent;
      case 'CRITICAL':
        return IncidentPriority.critical;
      default:
        return IncidentPriority.normal;
    }
  }

  SyncStatus _parseSyncStatus(int status) {
    switch (status) {
      case 0:
        return SyncStatus.pending;
      case 1:
        return SyncStatus.synced;
      case 2:
        return SyncStatus.error;
      default:
        return SyncStatus.pending;
    }
  }

  Trade? _parseTrade(String? trade) {
    if (trade == null) return null;
    switch (trade.toLowerCase()) {
      case 'masonry':
        return Trade.masonry;
      case 'plumbing':
        return Trade.plumbing;
      case 'electrical':
        return Trade.electrical;
      case 'finishing':
        return Trade.finishing;
      default:
        return Trade.other;
    }
  }
}
