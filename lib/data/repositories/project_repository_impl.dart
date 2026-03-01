import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:strop_app/data/datasources/local/local_database.dart';
import 'package:strop_app/domain/entities/project.dart';
import 'package:strop_app/domain/repositories/project_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProjectRepositoryImpl implements ProjectRepository {
  ProjectRepositoryImpl(this._supabaseClient, this._localDb);

  final SupabaseClient _supabaseClient;
  final LocalDatabase _localDb;

  List<Project> _cached = [];

  @override
  Future<List<Project>> getProjects() async {
    try {
      final userId = _supabaseClient.auth.currentUser?.id;
      if (userId == null) return [];

      // Fetch projects where current user is a member
      final response = await _supabaseClient
          .from('project_members')
          .select('''
            project:projects(
              id,
              name,
              phase,
              cover_photo_url,
              location_gps,
              contingency_budget,
              geofence_radius_meters,
              is_active
            )
          ''')
          .eq('user_id', userId);

      final projects = <Project>[];

      for (final row in response as List<dynamic>) {
        final p = row['project'] as Map<String, dynamic>?;
        if (p == null) continue;
        if (p['is_active'] == false) continue;

        // Parse GPS from PostGIS GeoJSON point string if present
        double? lat;
        double? lng;
        final gps = p['location_gps'];
        if (gps != null) {
          // Supabase returns PostGIS as {"type":"Point","coordinates":[lng,lat]}
          try {
            if (gps is Map) {
              final coords = gps['coordinates'] as List<dynamic>?;
              if (coords != null && coords.length >= 2) {
                lng = (coords[0] as num).toDouble();
                lat = (coords[1] as num).toDouble();
              }
            }
          } on Exception catch (e) {
            debugPrint('Error parsing GPS for project ${p['id']}: $e');
          }
        }

        projects.add(
          Project(
            id: p['id'] as String,
            name: p['name'] as String,
            address: p['phase'] as String? ?? '',
            imageUrl: p['cover_photo_url'] as String?,
            latitude: lat,
            longitude: lng,
            contingencyBudget: (p['contingency_budget'] as num?)?.toDouble(),
            isActive: p['is_active'] as bool? ?? true,
            geofenceRadiusMeters: p['geofence_radius_meters'] as int? ?? 500,
            phaseText: p['phase'] as String?,
          ),
        );
      }

      _cached = projects;

      // Persist to SQLite for offline cold-start
      final rows = projects
          .map(
            (p) => {
              'id': p.id,
              'name': p.name,
              'phase': p.phaseText,
              'cover_photo_url': p.imageUrl,
              'gps_lat': p.latitude,
              'gps_lng': p.longitude,
              'contingency_budget': p.contingencyBudget,
              'geofence_radius_meters': p.geofenceRadiusMeters,
              'is_active': p.isActive,
            },
          )
          .toList();
      await _localDb.cacheProjects(rows);

      return projects;
    } on Exception catch (e) {
      debugPrint('ProjectRepositoryImpl.getProjects error: $e');
      // 1. Try in-memory
      if (_cached.isNotEmpty) return _cached;
      // 2. Fall back to SQLite (cold-start offline)
      try {
        final rows = await _localDb.getCachedProjects();
        if (rows.isNotEmpty) {
          _cached = rows
              .map(
                (Map<String, dynamic> r) => Project(
                  id: r['id'] as String,
                  name: r['name'] as String,
                  address: r['phase'] as String? ?? '',
                  imageUrl: r['cover_photo_url'] as String?,
                  latitude: r['gps_lat'] as double?,
                  longitude: r['gps_lng'] as double?,
                  contingencyBudget: r['contingency_budget'] as double?,
                  isActive: (r['is_active'] as int? ?? 1) == 1,
                  geofenceRadiusMeters:
                      r['geofence_radius_meters'] as int? ?? 500,
                  phaseText: r['phase'] as String?,
                ),
              )
              .toList();
          return _cached;
        }
      } on Exception catch (sqliteErr) {
        debugPrint('ProjectRepositoryImpl SQLite fallback error: $sqliteErr');
      }
      rethrow;
    }
  }

  @override
  Future<Project?> getNearestProject(double lat, double lng) async {
    final projects = _cached.isEmpty ? await getProjects() : _cached;

    if (projects.isEmpty) return null;

    Project? nearest;
    double minDist = double.infinity;

    for (final p in projects) {
      if (p.latitude == null || p.longitude == null) continue;
      final dist = _haversineDistance(lat, lng, p.latitude!, p.longitude!);
      if (dist < minDist) {
        minDist = dist;
        nearest = p;
      }
    }

    return nearest;
  }

  /// Haversine formula in meters
  double _haversineDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const r = 6371000.0; // Earth radius in meters
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  double _toRad(double degrees) => degrees * math.pi / 180;
}
