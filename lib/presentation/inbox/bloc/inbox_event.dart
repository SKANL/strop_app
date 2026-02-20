import 'package:equatable/equatable.dart';
import 'package:strop_app/domain/entities/incident.dart';

sealed class InboxEvent extends Equatable {
  const InboxEvent();

  @override
  List<Object?> get props => [];
}

class SubscribeToIncidents extends InboxEvent {}

class SearchIncidents extends InboxEvent {
  const SearchIncidents(this.query);
  final String query;

  @override
  List<Object?> get props => [query];
}

class ChangeTab extends InboxEvent {
  const ChangeTab(this.status);
  final IncidentStatus status;

  @override
  List<Object?> get props => [status];
}

class UpdateIncidentStatus extends InboxEvent {
  const UpdateIncidentStatus(this.incident, this.newStatus);
  final Incident incident;
  final IncidentStatus newStatus;

  @override
  List<Object?> get props => [incident, newStatus];
}

class DeleteIncident extends InboxEvent {
  const DeleteIncident(this.incident);
  final Incident incident;

  @override
  List<Object?> get props => [incident];
}
