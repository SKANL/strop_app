import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:strop_app/domain/entities/incident.dart';
import 'package:strop_app/domain/repositories/incident_repository.dart';
import 'package:strop_app/presentation/inbox/bloc/inbox_event.dart';
import 'package:strop_app/presentation/inbox/bloc/inbox_state.dart';

class InboxBloc extends Bloc<InboxEvent, InboxState> {
  InboxBloc({required IncidentRepository incidentRepository})
    : _incidentRepository = incidentRepository,
      super(InboxInitial()) {
    on<SubscribeToIncidents>(_onSubscribe);
    on<SearchIncidents>(_onSearch);
    on<ChangeTab>(_onChangeTab);
    on<UpdateIncidentStatus>(_onUpdateStatus);
    on<DeleteIncident>(_onDelete);
  }

  final IncidentRepository _incidentRepository;

  // Local cache of all incidents from the stream to apply filters on
  List<Incident> _allIncidents = [];

  Future<void> _onSubscribe(
    SubscribeToIncidents event,
    Emitter<InboxState> emit,
  ) async {
    emit(InboxLoading());

    await emit.forEach<List<Incident>>(
      _incidentRepository.incidentsStream,
      onData: (incidents) {
        _allIncidents = incidents;
        // When we receive new data, we assume we are already in a Loaded state
        // or we transition to it. We need to preserve current filters.
        if (state is InboxLoaded) {
          final currentState = state as InboxLoaded;
          return _filterIncidents(
            incidents,
            currentState.currentTab,
            currentState.searchQuery,
          );
        } else {
          // Default initial state
          return _filterIncidents(
            incidents,
            IncidentStatus.pending,
            '',
          );
        }
      },
      onError: (error, stackTrace) {
        return InboxError(error.toString());
      },
    );
  }

  Future<void> _onSearch(
    SearchIncidents event,
    Emitter<InboxState> emit,
  ) async {
    if (state is InboxLoaded) {
      final currentState = state as InboxLoaded;
      emit(
        _filterIncidents(
          _allIncidents,
          currentState.currentTab,
          event.query,
        ),
      );
    }
  }

  Future<void> _onChangeTab(
    ChangeTab event,
    Emitter<InboxState> emit,
  ) async {
    if (state is InboxLoaded) {
      final currentState = state as InboxLoaded;
      emit(
        _filterIncidents(
          _allIncidents,
          event.status,
          currentState.searchQuery,
        ),
      );
    }
  }

  Future<void> _onUpdateStatus(
    UpdateIncidentStatus event,
    Emitter<InboxState> emit,
  ) async {
    try {
      await _incidentRepository.updateIncident(
        event.incident.copyWith(status: event.newStatus),
      );
      // The stream will naturally update the UI
    } on Exception {
      // Optimistic update failed?
      // In a real app we might show a snackbar via a side-effect listener
      // For now, we just log or ignore, the stream won't update
    }
  }

  Future<void> _onDelete(
    DeleteIncident event,
    Emitter<InboxState> emit,
  ) async {
    // Delete not implemented in repository for this demo,
    // but conceptually similar to update
  }

  InboxLoaded _filterIncidents(
    List<Incident> incidents,
    IncidentStatus tab,
    String query,
  ) {
    final filtered = incidents.where((incident) {
      final matchesTab = incident.status == tab;
      if (!matchesTab) return false;

      if (query.isEmpty) return true;

      final q = query.toLowerCase();
      final matchesSearch =
          incident.title.toLowerCase().contains(q) ||
          (incident.description?.toLowerCase().contains(q) ?? false) ||
          incident.location.toLowerCase().contains(q);

      return matchesSearch;
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return InboxLoaded(
      incidents: filtered,
      currentTab: tab,
      searchQuery: query,
    );
  }
}
