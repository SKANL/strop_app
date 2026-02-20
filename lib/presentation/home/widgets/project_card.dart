import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:strop_app/domain/entities/project.dart';

class ProjectCard extends StatelessWidget {
  const ProjectCard({
    required this.project,
    this.distance,
    super.key,
  });

  final Project project;
  final double? distance; // Distance in km

  @override
  Widget build(BuildContext context) {
    final isNearby = distance != null && distance! < 0.1; // < 100m

    return shadcn.Card(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: () {
          unawaited(context.push('/project-dashboard', extra: project));
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Project Image
            if (project.imageUrl != null)
              SizedBox(
                height: 150,
                width: double.infinity,
                child: Hero(
                  tag: 'project_image_${project.id}',
                  child: CachedNetworkImage(
                    imageUrl: project.imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[300],
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[300],
                      child: const Icon(
                        Icons.business,
                        size: 64,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
              )
            else
              Container(
                height: 150,
                width: double.infinity,
                color: Colors.grey[300],
                child: const Icon(
                  Icons.business,
                  size: 64,
                  color: Colors.grey,
                ),
              ),

            // Project Info
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Row with Distance Badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          project.name,
                          style: shadcn.Theme.of(context).typography.h4
                              .copyWith(
                                fontSize: 18,
                              ),
                        ),
                      ),
                      if (distance != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isNearby ? Colors.green : Colors.blue,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.location_on,
                                size: 12,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isNearby
                                    ? 'Estás aquí'
                                    : '${distance!.toStringAsFixed(1)} km',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Address
                  Text(
                    project.address,
                    style: shadcn.Theme.of(context).typography.small.copyWith(
                      color: shadcn.Theme.of(
                        context,
                      ).colorScheme.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Status Row
                  Row(
                    children: [
                      // Critical Incidents Badge
                      if (project.criticalIncidents > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.warning,
                                size: 12,
                                color: Colors.red,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${project.criticalIncidents} críticos',
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (project.criticalIncidents > 0)
                        const SizedBox(width: 8),

                      // Sync Status
                      Icon(
                        project.isSynced ? Icons.check_circle : Icons.pending,
                        size: 16,
                        color: project.isSynced ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        project.isSynced ? 'Synced' : 'Pending',
                        style: shadcn.Theme.of(context).typography.small
                            .copyWith(
                              color: project.isSynced
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
