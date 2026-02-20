import 'package:strop_app/domain/entities/incident.dart';

abstract class IncidentRepository {
  Future<List<Incident>> getIncidents();
  Future<void> createIncident(Incident incident);
  Future<void> updateIncident(Incident incident);
  Future<void> syncPendingIncidents();
  Stream<List<Incident>> get incidentsStream;
  Future<int> getPendingIncidentCount();
}
