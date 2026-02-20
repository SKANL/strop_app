import 'package:equatable/equatable.dart';
import 'package:geolocator/geolocator.dart';
import 'package:strop_app/domain/entities/project.dart';

sealed class ProjectState extends Equatable {
  const ProjectState();

  @override
  List<Object?> get props => [];
}

class ProjectInitial extends ProjectState {}

class ProjectLoading extends ProjectState {}

class ProjectLoaded extends ProjectState {
  const ProjectLoaded({
    required this.projects,
    this.userLocation,
    this.distances = const {},
  });

  final List<Project> projects;
  final Position? userLocation;
  final Map<String, double> distances; // projectId -> distance in km

  @override
  List<Object?> get props => [projects, userLocation, distances];
}

class ProjectError extends ProjectState {
  const ProjectError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
