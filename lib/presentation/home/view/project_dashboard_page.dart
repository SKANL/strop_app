import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart' show BackButton, Colors, Icons;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Colors;
import 'package:strop_app/app/di/service_locator.dart';
import 'package:strop_app/domain/entities/incident.dart';
import 'package:strop_app/domain/entities/project.dart';
import 'package:strop_app/domain/repositories/incident_repository.dart';
import 'package:url_launcher/url_launcher.dart';

class ProjectDashboardPage extends StatelessWidget {
  const ProjectDashboardPage({
    required this.project,
    super.key,
  });

  final Project project;

  Future<void> _openMaps() async {
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${project.latitude},${project.longitude}',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      headers: [
        AppBar(
          title: Text(project.name),
          leading: [const BackButton()],
        ),
      ],
      child: StreamBuilder<List<Incident>>(
        stream: sl<IncidentRepository>().incidentsStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final incidents = snapshot.data!
              .where((i) => i.projectId == project.id || i.location == project.name)
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProjectHeader(project: project, onOpenMaps: _openMaps),
                _StatsSection(incidents: incidents),
                _IncidentSection(incidents: incidents),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────────────

class _ProjectHeader extends StatelessWidget {
  const _ProjectHeader(
      {required this.project, required this.onOpenMaps});

  final Project project;
  final VoidCallback onOpenMaps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Hero image / placeholder
    Widget image = Container(
      height: 200,
      width: double.infinity,
      color: theme.colorScheme.muted,
      child: Icon(Icons.domain_rounded,
          size: 72, color: theme.colorScheme.mutedForeground),
    );

    if (project.imageUrl != null) {
      image = SizedBox(
        height: 200,
        width: double.infinity,
        child: Hero(
          tag: 'project_image_${project.id}',
          child: CachedNetworkImage(
            imageUrl: project.imageUrl!,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              color: theme.colorScheme.muted,
              child: const Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (_, __, ___) => Container(
              color: theme.colorScheme.muted,
              child: Icon(Icons.domain_rounded,
                  size: 72,
                  color: theme.colorScheme.mutedForeground),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        image,
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(project.name, style: theme.typography.h3),
              const Gap(6),
              Row(
                children: [
                  Icon(Icons.location_on_outlined,
                      size: 14,
                      color: theme.colorScheme.mutedForeground),
                  const Gap(4),
                  Expanded(
                    child: Text(
                      project.address,
                      style: theme.typography.small.copyWith(
                          color: theme.colorScheme.mutedForeground),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const Gap(14),
              SizedBox(
                width: double.infinity,
                child: Button(
                  style: const ButtonStyle.outline(),
                  leading: const Icon(Icons.directions_outlined, size: 16),
                  onPressed: onOpenMaps,
                  child: const Text('Cómo llegar'),
                ),
              ),
              const Gap(16),
              Container(height: 1, color: theme.colorScheme.border),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Stats ─────────────────────────────────────────────────────────────────────

class _StatsSection extends StatelessWidget {
  const _StatsSection({required this.incidents});

  final List<Incident> incidents;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = incidents.length;
    final byPriority = <IncidentPriority, int>{};
    final byStatus = <IncidentStatus, int>{};
    final byTrade = <Trade, int>{};

    for (final i in incidents) {
      byPriority[i.priority] = (byPriority[i.priority] ?? 0) + 1;
      byStatus[i.status] = (byStatus[i.status] ?? 0) + 1;
      if (i.assignedTrade != null) {
        byTrade[i.assignedTrade!] = (byTrade[i.assignedTrade!] ?? 0) + 1;
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Estadísticas', style: theme.typography.h4),
          const Gap(14),

          // Total card
          _StatTile(
            label: 'Total de incidencias',
            value: total.toString(),
            color: Colors.blue,
          ),
          const Gap(12),

          // Priority row
          Text('Por Prioridad',
              style: theme.typography.p
                  .copyWith(fontWeight: FontWeight.w600)),
          const Gap(8),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Normal',
                  value:
                      (byPriority[IncidentPriority.normal] ?? 0).toString(),
                  color: Colors.green,
                ),
              ),
              const Gap(8),
              Expanded(
                child: _MiniStat(
                  label: 'Urgente',
                  value:
                      (byPriority[IncidentPriority.urgent] ?? 0).toString(),
                  color: Colors.orange,
                ),
              ),
              const Gap(8),
              Expanded(
                child: _MiniStat(
                  label: 'Crítico',
                  value: (byPriority[IncidentPriority.critical] ?? 0)
                      .toString(),
                  color: Colors.red,
                ),
              ),
            ],
          ),
          const Gap(16),

          // Status row
          Text('Por Estado',
              style: theme.typography.p
                  .copyWith(fontWeight: FontWeight.w600)),
          const Gap(8),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Pendiente',
                  value:
                      (byStatus[IncidentStatus.open] ?? 0).toString(),
                  color: theme.colorScheme.mutedForeground,
                ),
              ),
              const Gap(8),
              Expanded(
                child: _MiniStat(
                  label: 'En Revisión',
                  value:
                      (byStatus[IncidentStatus.inReview] ?? 0).toString(),
                  color: Colors.blue,
                ),
              ),
              const Gap(8),
              Expanded(
                child: _MiniStat(
                  label: 'Completado',
                  value: (byStatus[IncidentStatus.closed] ?? 0).toString(),
                  color: Colors.green,
                ),
              ),
            ],
          ),

          // By trade
          if (byTrade.isNotEmpty) ...[
            const Gap(16),
            Text('Por Gremio',
                style: theme.typography.p
                    .copyWith(fontWeight: FontWeight.w600)),
            const Gap(8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: byTrade.entries.map((e) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.muted,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_tradeLabel(e.key)}: ${e.value}',
                    style: theme.typography.small,
                  ),
                );
              }).toList(),
            ),
          ],

          const Gap(16),
          Container(height: 1, color: theme.colorScheme.border),
        ],
      ),
    );
  }

  String _tradeLabel(Trade trade) => switch (trade) {
        Trade.masonry => 'Albañilería',
        Trade.plumbing => 'Plomería',
        Trade.electrical => 'Eléctrico',
        Trade.finishing => 'Acabados',
        Trade.other => 'Otro',
      };
}

// ── Incident list ─────────────────────────────────────────────────────────────

class _IncidentSection extends StatelessWidget {
  const _IncidentSection({required this.incidents});

  final List<Incident> incidents;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (incidents.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Center(
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded,
                    size: 32, color: Colors.green),
              ),
              const Gap(16),
              Text(
                'Sin incidencias en este proyecto',
                style: theme.typography.p.copyWith(
                    color: theme.colorScheme.mutedForeground),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ).animate().fade().scale(),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Incidencias recientes', style: theme.typography.h4),
          const Gap(12),
          ...incidents.asMap().entries.map((e) {
            return _IncidentItem(incident: e.value)
                .animate(delay: (80 * e.key).ms)
                .fadeIn()
                .slideX(begin: 0.15, end: 0);
          }),
        ],
      ),
    );
  }
}

class _IncidentItem extends StatelessWidget {
  const _IncidentItem({required this.incident});

  final Incident incident;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => context.push('/expediente', extra: incident),
      child: Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Priority dot
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _priorityColor(incident.priority),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const Gap(12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      incident.title,
                      style: theme.typography.p
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (incident.specificLocation != null) ...[
                      const Gap(2),
                      Text(
                        incident.specificLocation!,
                        style: theme.typography.small.copyWith(
                            color: theme.colorScheme.mutedForeground),
                      ),
                    ],
                    const Gap(6),
                    Text(
                      _formatDate(incident.createdAt),
                      style: theme.typography.small.copyWith(
                          color: theme.colorScheme.mutedForeground,
                          fontSize: 11),
                    ),
                  ],
                ),
              ),
              const Gap(8),

              // Status badge
              _StatusBadge(status: incident.status),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Color _priorityColor(IncidentPriority p) => switch (p) {
        IncidentPriority.normal => Colors.green,
        IncidentPriority.urgent => Colors.orange,
        IncidentPriority.critical => Colors.red,
      };

  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays == 0) return 'Hoy';
    if (diff.inDays == 1) return 'Ayer';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} días';
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final IncidentStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      IncidentStatus.open => (
          'Pendiente',
          Theme.of(context).colorScheme.muted,
          Theme.of(context).colorScheme.mutedForeground
        ),
      IncidentStatus.inReview => (
          'En Revisión',
          Colors.blue.withValues(alpha: 0.12),
          Colors.blue
        ),
      IncidentStatus.closed => (
          'Completado',
          Colors.green.withValues(alpha: 0.12),
          Colors.green
        ),
      IncidentStatus.rejected => (
          'Rechazado',
          Colors.red.withValues(alpha: 0.12),
          Colors.red
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

// ── Shared stat widgets ───────────────────────────────────────────────────────

class _StatTile extends StatelessWidget {
  const _StatTile(
      {required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(theme.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.typography.p),
          Text(
            value,
            style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(
      {required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(theme.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: theme.typography.small
                .copyWith(color: theme.colorScheme.mutedForeground),
            textAlign: TextAlign.center,
          ),
          const Gap(4),
          Text(
            value,
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}

