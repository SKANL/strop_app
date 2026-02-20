import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:strop_app/app/di/service_locator.dart';
import 'package:strop_app/core/services/location_service.dart';
import 'package:strop_app/domain/repositories/project_repository.dart';
import 'package:strop_app/presentation/home/bloc/project_bloc.dart';
import 'package:strop_app/presentation/home/bloc/project_event.dart';
import 'package:strop_app/presentation/home/bloc/project_state.dart';
import 'package:strop_app/presentation/home/widgets/project_card.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ProjectBloc(
        projectRepository: sl<ProjectRepository>(),
        locationService: sl<LocationService>(),
      )..add(LoadProjects()),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Proyectos'),
          actions: [
            BlocBuilder<ProjectBloc, ProjectState>(
              builder: (context, state) {
                return IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    context.read<ProjectBloc>().add(RefreshLocation());
                  },
                );
              },
            ),
          ],
        ),
        body: BlocBuilder<ProjectBloc, ProjectState>(
          builder: (context, state) {
            if (state is ProjectLoading) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (state is ProjectError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      state.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    shadcn.Button.primary(
                      onPressed: () {
                        context.read<ProjectBloc>().add(LoadProjects());
                      },
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ).animate().fade().shake();
            }

            if (state is ProjectLoaded) {
              if (state.projects.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.business_outlined,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No hay proyectos disponibles',
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  context.read<ProjectBloc>().add(RefreshLocation());
                  // Wait a bit for the refresh to complete
                  await Future<void>.delayed(const Duration(seconds: 1));
                },
                child: Column(
                  children: [
                    // Location status banner
                    if (state.userLocation == null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        color: Colors.orange[100],
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_off,
                              size: 20,
                              color: Colors.orange[900],
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Ubicación no disponible. '
                                'Los proyectos no están '
                                'ordenados por distancia.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange[900],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Project list
                    Expanded(
                      child: ListView.builder(
                        itemCount: state.projects.length,
                        itemBuilder: (context, index) {
                          final project = state.projects[index];
                          final distance = state.distances[project.id];

                          return ProjectCard(
                                project: project,
                                distance: distance,
                              )
                              .animate(delay: (100 * index).ms)
                              .fadeIn()
                              .slideY(
                                begin: 0.1,
                                end: 0,
                              );
                        },
                      ),
                    ),
                  ],
                ),
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}
