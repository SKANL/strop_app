import 'package:strop_app/domain/entities/project.dart';

abstract class ProjectRepository {
  Future<List<Project>> getProjects();
  Future<Project?> getNearestProject(double lat, double long);
}
