import 'package:flutter/material.dart' show RefreshIndicator;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
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
        headers: [
          AppBar(
            title: const Text('Proyectos'),
            trailing: [
              Semantics(
                label: 'Actualizar ubicación',
                child: IconButton(
                  variance: ButtonVariance.ghost,
                  icon: const Icon(Icons.my_location_rounded, size: 20),
                  onPressed: () =>
                      context.read<ProjectBloc>().add(RefreshLocation()),
                ),
              ),
            ],
          ),
        ],
        child: BlocBuilder<ProjectBloc, ProjectState>(
          builder: (context, state) {
            if (state is ProjectLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is ProjectError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .destructive
                              .withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.wifi_off_rounded,
                          size: 36,
                          color: Theme.of(context).colorScheme.destructive,
                        ),
                      ),
                      const Gap(16),
                      Text(
                        state.message,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).typography.p.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .mutedForeground,
                            ),
                      ),
                      const Gap(20),
                      Button(
                        style: const ButtonStyle.outline(),
                        onPressed: () =>
                            context.read<ProjectBloc>().add(LoadProjects()),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              ).animate().fade().shake();
            }

            if (state is ProjectLoaded) {
              if (state.projects.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.muted,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.domain_rounded,
                            size: 40,
                            color: Theme.of(context)
                                .colorScheme
                                .mutedForeground,
                          ),
                        ),
                        const Gap(20),
                        Text(
                          'No hay proyectos disponibles',
                          style:
                              Theme.of(context).typography.p.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .mutedForeground,
                                  ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  context.read<ProjectBloc>().add(RefreshLocation());
                  await Future<void>.delayed(const Duration(seconds: 1));
                },
                child: CustomScrollView(
                  slivers: [
                    // ── Location warning banner ──────────────────────────
                    if (state.userLocation == null)
                      SliverToBoxAdapter(
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFfef3c7),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFFf59e0b).withValues(
                                  alpha: 0.5),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.location_off_rounded,
                                size: 16,
                                color: Color(0xFF92400e),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Ubicación no disponible. Los proyectos no están ordenados por distancia.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF92400e),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // ── Project list ────────────────────────────────────
                    SliverPadding(
                      padding: const EdgeInsets.all(12),
                      sliver: SliverList.builder(
                        itemCount: state.projects.length,
                        itemBuilder: (context, index) {
                          final project = state.projects[index];
                          final distance = state.distances[project.id];

                          return ProjectCard(
                            project: project,
                            distance: distance,
                          )
                              .animate(delay: (80 * index).ms)
                              .fadeIn()
                              .slideY(begin: 0.08, end: 0);
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
