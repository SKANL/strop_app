import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart' show Colors, Icons;
import 'package:go_router/go_router.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Colors;
import 'package:strop_app/domain/entities/project.dart';

class ProjectCard extends StatelessWidget {
  const ProjectCard({
    required this.project,
    this.distance,
    super.key,
  });

  final Project project;
  final double? distance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNearby = distance != null && distance! < 0.1;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(theme.radiusLg),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () =>
                unawaited(context.push('/project-dashboard', extra: project)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Image ───────────────────────────────────────────────
                _ProjectImage(project: project),

                // ── Body ────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name + distance badge
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              project.name,
                              style: theme.typography.h4
                                  .copyWith(fontSize: 15),
                            ),
                          ),
                          if (distance != null) ...[
                            const SizedBox(width: 8),
                            _DistanceBadge(
                                km: distance!, isNearby: isNearby),
                          ],
                        ],
                      ),
                      const SizedBox(height: 5),

                      // Address
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 12,
                            color: theme.colorScheme.mutedForeground,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              project.address,
                              style: theme.typography.small.copyWith(
                                color: theme.colorScheme.mutedForeground,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Divider
                      Container(
                        height: 1,
                        color: theme.colorScheme.border,
                      ),
                      const SizedBox(height: 8),

                      // Status row
                      Row(
                        children: [
                          _SyncBadge(isSynced: project.isSynced),
                          if (project.criticalIncidents > 0) ...[
                            const SizedBox(width: 8),
                            _CriticalBadge(
                                count: project.criticalIncidents),
                          ],
                          const Spacer(),
                          Icon(
                            Icons.chevron_right,
                            size: 16,
                            color: theme.colorScheme.mutedForeground,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _ProjectImage extends StatelessWidget {
  const _ProjectImage({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget placeholder = Container(
      height: 140,
      width: double.infinity,
      color: theme.colorScheme.muted,
      child: Icon(
        Icons.domain_rounded,
        size: 48,
        color: theme.colorScheme.mutedForeground,
      ),
    );

    if (project.imageUrl == null) return placeholder;

    return SizedBox(
      height: 140,
      width: double.infinity,
      child: Hero(
        tag: 'project_image_${project.id}',
        child: CachedNetworkImage(
          imageUrl: project.imageUrl!,
          fit: BoxFit.cover,
          placeholder: (_, __) => placeholder,
          errorWidget: (_, __, ___) => placeholder,
        ),
      ),
    );
  }
}

class _DistanceBadge extends StatelessWidget {
  const _DistanceBadge({required this.km, required this.isNearby});

  final double km;
  final bool isNearby;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        isNearby ? Colors.green : theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_on, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            isNearby ? 'Estás aquí' : '${km.toStringAsFixed(1)} km',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CriticalBadge extends StatelessWidget {
  const _CriticalBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: Colors.red.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 11, color: Colors.red),
          const SizedBox(width: 3),
          Text(
            '$count críticos',
            style: const TextStyle(
              color: Colors.red,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncBadge extends StatelessWidget {
  const _SyncBadge({required this.isSynced});

  final bool isSynced;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isSynced ? Colors.green : Colors.orange;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isSynced
              ? Icons.cloud_done_outlined
              : Icons.cloud_upload_outlined,
          size: 13,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          isSynced ? 'Sincronizado' : 'Pendiente',
          style: theme.typography.small
              .copyWith(color: color, fontSize: 11),
        ),
      ],
    );
  }
}
