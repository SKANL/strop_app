import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:strop_app/core/services/location_service.dart';
import 'package:strop_app/domain/entities/project.dart';
import 'package:strop_app/domain/repositories/project_repository.dart';
import 'package:strop_app/presentation/home/bloc/project_event.dart';
import 'package:strop_app/presentation/home/bloc/project_state.dart';

class ProjectBloc extends Bloc<ProjectEvent, ProjectState> {
  ProjectBloc({
    required ProjectRepository projectRepository,
    required LocationService locationService,
  }) : _projectRepository = projectRepository,
       _locationService = locationService,
       super(ProjectInitial()) {
    on<LoadProjects>(_onLoadProjects);
    on<RefreshLocation>(_onRefreshLocation);
  }

  final ProjectRepository _projectRepository;
  final LocationService _locationService;

  Future<void> _onLoadProjects(
    LoadProjects event,
    Emitter<ProjectState> emit,
  ) async {
    emit(ProjectLoading());

    try {
      // Get user location
      final position = await _locationService.getCurrentPosition();

      // Load projects
      final projects = await _projectRepository.getProjects();

      // Calculate distances if location is available
      final distances = <String, double>{};
      if (position != null) {
        for (final project in projects) {
          final distance = _locationService.calculateDistance(
            position.latitude,
            position.longitude,
            project.latitude,
            project.longitude,
          );
          distances[project.id] = distance;
        }

        // Sort projects by distance (nearest first)
        projects.sort((a, b) {
          final distA = distances[a.id] ?? double.infinity;
          final distB = distances[b.id] ?? double.infinity;
          return distA.compareTo(distB);
        });
      }

      emit(
        ProjectLoaded(
          projects: projects,
          userLocation: position,
          distances: distances,
        ),
      );
    } on Exception catch (e) {
      emit(ProjectError('Failed to load projects: $e'));
    }
  }

  Future<void> _onRefreshLocation(
    RefreshLocation event,
    Emitter<ProjectState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ProjectLoaded) return;

    try {
      // Get fresh location
      final position = await _locationService.getCurrentPosition();

      if (position == null) {
        // Keep current state if location unavailable
        return;
      }

      // Recalculate distances
      final distances = <String, double>{};
      final projects = List<Project>.from(currentState.projects);

      for (final project in projects) {
        final distance = _locationService.calculateDistance(
          position.latitude,
          position.longitude,
          project.latitude,
          project.longitude,
        );
        distances[project.id] = distance;
      }

      // Re-sort by distance
      projects.sort((a, b) {
        final distA = distances[a.id] ?? double.infinity;
        final distB = distances[b.id] ?? double.infinity;
        return distA.compareTo(distB);
      });

      emit(
        ProjectLoaded(
          projects: projects,
          userLocation: position,
          distances: distances,
        ),
      );
    } on Exception {
      // Keep current state on error
    }
  }
}
