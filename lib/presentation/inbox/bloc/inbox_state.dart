import 'package:equatable/equatable.dart';
import 'package:strop_app/domain/entities/incident.dart';

sealed class InboxState extends Equatable {
  const InboxState();

  @override
  List<Object?> get props => [];
}

class InboxInitial extends InboxState {}

class InboxLoading extends InboxState {}

class InboxLoaded extends InboxState {
  const InboxLoaded({
    required this.incidents,
    required this.currentTab,
    this.searchQuery = '',
  });

  final List<Incident> incidents;
  final IncidentStatus currentTab;
  final String searchQuery;

  InboxLoaded copyWith({
    List<Incident>? incidents,
    IncidentStatus? currentTab,
    String? searchQuery,
  }) {
    return InboxLoaded(
      incidents: incidents ?? this.incidents,
      currentTab: currentTab ?? this.currentTab,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  @override
  List<Object?> get props => [incidents, currentTab, searchQuery];
}

class InboxError extends InboxState {
  const InboxError(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}
