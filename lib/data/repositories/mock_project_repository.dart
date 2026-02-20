import 'package:strop_app/domain/entities/project.dart';
import 'package:strop_app/domain/repositories/project_repository.dart';

class MockProjectRepository implements ProjectRepository {
  final List<Project> _projects = [
    const Project(
      id: '1',
      name: 'Torre Meriden',
      address: 'Av. Cabildo 1234, Buenos Aires',
      imageUrl: 'https://picsum.photos/400/200',
      latitude: -34.5678,
      longitude: -58.4567,
      criticalIncidents: 3,
    ),
    const Project(
      id: '2',
      name: 'Complejo Horizons',
      address: 'Libertador 4500, Buenos Aires',
      imageUrl: 'https://picsum.photos/400/201',
      latitude: -34.5500,
      longitude: -58.4400,
      isSynced: false,
    ),
    const Project(
      id: '3',
      name: 'Oficinas WeWork',
      address: 'Corrientes 800, Buenos Aires',
      imageUrl: 'https://picsum.photos/400/202',
      latitude: -34.6037,
      longitude: -58.3816,
      criticalIncidents: 1,
    ),
  ];

  @override
  Future<List<Project>> getProjects() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return _projects;
  }

  @override
  Future<Project?> getNearestProject(double lat, double long) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    // Simple mock logic: just return the first one as "current location" match
    // In reality would calculate distance
    return _projects.first;
  }
}
