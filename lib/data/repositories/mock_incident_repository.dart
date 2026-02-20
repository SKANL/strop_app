import 'dart:async';
import 'package:strop_app/domain/entities/incident.dart';
import 'package:strop_app/domain/repositories/incident_repository.dart';

class MockIncidentRepository implements IncidentRepository {

  MockIncidentRepository() {
    _controller.add(_incidents);
  }
  final _controller = StreamController<List<Incident>>.broadcast();

  final List<Incident> _incidents = [
    Incident(
      id: '1',
      title: 'Broken pipe in basement',
      location: 'Basement Level 2',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      priority: IncidentPriority.critical,
      syncStatus: SyncStatus.synced,
      photos: const ['https://picsum.photos/200'],
    ),
    Incident(
      id: '2',
      title: 'Missing safety rail',
      location: 'Staircase A',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      priority: IncidentPriority.urgent,
      status: IncidentStatus.inReview,
      syncStatus: SyncStatus.synced,
      photos: const ['https://picsum.photos/201'],
    ),
    Incident(
      id: '3',
      title: 'Debris in hallway',
      location: 'Corridor 3F',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      status: IncidentStatus.done,
      syncStatus: SyncStatus.synced,
      photos: const ['https://picsum.photos/202'],
    ),
  ];

  @override
  Stream<List<Incident>> get incidentsStream async* {
    yield List.of(_incidents);
    yield* _controller.stream;
  }

  @override
  Future<List<Incident>> getIncidents() async {
    await Future<void>.delayed(
      const Duration(milliseconds: 800),
    ); // Simulate network
    return _incidents;
  }

  @override
  Future<void> createIncident(Incident incident) async {
    await Future<void>.delayed(
      const Duration(milliseconds: 1500),
    ); // Simulate upload

    // In a real app this would likely return the created incident with ID
    // For now we assume the ID is generated client-side or we ignore it
    _incidents.insert(0, incident.copyWith(syncStatus: SyncStatus.synced));
    _controller.add(List.from(_incidents));
  }

  @override
  Future<void> updateIncident(Incident incident) async {
    await Future<void>.delayed(const Duration(milliseconds: 1000));
    final index = _incidents.indexWhere((i) => i.id == incident.id);
    if (index != -1) {
      _incidents[index] = incident;
      _controller.add(List.from(_incidents));
    }
  }

  @override
  Future<void> syncPendingIncidents() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    // Simulate syncing all pending
    for (var i = 0; i < _incidents.length; i++) {
      if (_incidents[i].syncStatus != SyncStatus.synced) {
        _incidents[i] = _incidents[i].copyWith(syncStatus: SyncStatus.synced);
      }
    }
    _controller.add(List.from(_incidents));
  }

  @override
  Future<int> getPendingIncidentCount() async {
    return _incidents.where((i) => i.syncStatus != SyncStatus.synced).length;
  }
}
