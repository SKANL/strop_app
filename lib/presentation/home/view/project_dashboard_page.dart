import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
      appBar: AppBar(
        title: Text(project.name),
      ),
      body: StreamBuilder<List<Incident>>(
        stream: sl<IncidentRepository>().incidentsStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // Filter incidents by project location
          final incidents =
              snapshot.data!
                  .where((incident) => incident.location == project.name)
                  .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                _buildStats(incidents),
                _buildIncidentList(incidents),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      children: [
        // Project Image
        if (project.imageUrl != null)
          SizedBox(
            height: 200,
            width: double.infinity,
            child: Hero(
              tag: 'project_image_${project.id}',
              child: Image.network(
                project.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[300],
                    child: const Icon(
                      Icons.business,
                      size: 80,
                      color: Colors.grey,
                    ),
                  );
                },
              ),
            ),
          )
        else
          Container(
            height: 200,
            width: double.infinity,
            color: Colors.grey[300],
            child: const Icon(
              Icons.business,
              size: 80,
              color: Colors.grey,
            ),
          ),

        // Project Info
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                project.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      project.address,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _openMaps,
                  icon: const Icon(Icons.directions),
                  label: const Text('Cómo llegar'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStats(List<Incident> incidents) {
    // Calculate statistics
    final total = incidents.length;
    final byPriority = <IncidentPriority, int>{};
    final byStatus = <IncidentStatus, int>{};
    final byTrade = <Trade, int>{};

    for (final incident in incidents) {
      byPriority[incident.priority] = (byPriority[incident.priority] ?? 0) + 1;
      byStatus[incident.status] = (byStatus[incident.status] ?? 0) + 1;
      if (incident.assignedTrade != null) {
        byTrade[incident.assignedTrade!] =
            (byTrade[incident.assignedTrade!] ?? 0) + 1;
      }
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Estadísticas',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Total
          _StatCard(
            title: 'Total de Incidentes',
            value: total.toString(),
            color: Colors.blue,
          ),
          const SizedBox(height: 12),

          // By Priority
          const Text(
            'Por Prioridad',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Normal',
                  value: (byPriority[IncidentPriority.normal] ?? 0).toString(),
                  color: Colors.green,
                  compact: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  title: 'Urgente',
                  value: (byPriority[IncidentPriority.urgent] ?? 0).toString(),
                  color: Colors.orange,
                  compact: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  title: 'Crítico',
                  value: (byPriority[IncidentPriority.critical] ?? 0)
                      .toString(),
                  color: Colors.red,
                  compact: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // By Status
          const Text(
            'Por Estado',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Pendiente',
                  value: (byStatus[IncidentStatus.pending] ?? 0).toString(),
                  color: Colors.grey,
                  compact: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  title: 'En Revisión',
                  value: (byStatus[IncidentStatus.inReview] ?? 0).toString(),
                  color: Colors.blue,
                  compact: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  title: 'Completado',
                  value: (byStatus[IncidentStatus.done] ?? 0).toString(),
                  color: Colors.green,
                  compact: true,
                ),
              ),
            ],
          ),

          // By Trade (if any)
          if (byTrade.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Por Gremio',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: byTrade.entries.map((entry) {
                return Chip(
                  label: Text(
                    '${_tradeLabel(entry.key)}: ${entry.value}',
                    style: const TextStyle(fontSize: 12),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIncidentList(List<Incident> incidents) {
    if (incidents.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: const Center(
          child: Column(
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 64,
                color: Colors.green,
              ),
              SizedBox(height: 16),
              Text(
                'No hay incidentes en este proyecto',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ).animate().fade().scale(),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Incidentes Recientes',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...incidents.asMap().entries.map((entry) {
            final index = entry.key;
            final incident = entry.value;
            return _IncidentListItem(incident: incident)
                .animate(delay: (100 * index).ms)
                .fadeIn()
                .slideX(begin: 0.2, end: 0);
          }),
        ],
      ),
    );
  }

  String _tradeLabel(Trade trade) {
    switch (trade) {
      case Trade.masonry:
        return 'Albañilería';
      case Trade.plumbing:
        return 'Plomería';
      case Trade.electrical:
        return 'Eléctrico';
      case Trade.finishing:
        return 'Acabados';
      case Trade.other:
        return 'Otro';
    }
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.color,
    this.compact = false,
  });

  final String title;
  final String value;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Column(
        crossAxisAlignment: compact
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: compact ? 12 : 14,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: compact ? 4 : 8),
          Text(
            value,
            style: TextStyle(
              fontSize: compact ? 20 : 32,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _IncidentListItem extends StatelessWidget {
  const _IncidentListItem({required this.incident});

  final Incident incident;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _priorityColor(incident.priority),
          child: Icon(
            _priorityIcon(incident.priority),
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          incident.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (incident.specificLocation != null)
              Text(incident.specificLocation!),
            Text(
              _formatDate(incident.createdAt),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: Chip(
          label: Text(
            _statusLabel(incident.status),
            style: const TextStyle(fontSize: 10),
          ),
          backgroundColor: _statusColor(incident.status),
        ),
      ),
    );
  }

  Color _priorityColor(IncidentPriority priority) {
    switch (priority) {
      case IncidentPriority.normal:
        return Colors.green;
      case IncidentPriority.urgent:
        return Colors.orange;
      case IncidentPriority.critical:
        return Colors.red;
    }
  }

  IconData _priorityIcon(IncidentPriority priority) {
    switch (priority) {
      case IncidentPriority.normal:
        return Icons.info;
      case IncidentPriority.urgent:
        return Icons.warning;
      case IncidentPriority.critical:
        return Icons.error;
    }
  }

  String _statusLabel(IncidentStatus status) {
    switch (status) {
      case IncidentStatus.pending:
        return 'Pendiente';
      case IncidentStatus.inReview:
        return 'En Revisión';
      case IncidentStatus.done:
        return 'Completado';
    }
  }

  Color _statusColor(IncidentStatus status) {
    switch (status) {
      case IncidentStatus.pending:
        return Colors.grey[300]!;
      case IncidentStatus.inReview:
        return Colors.blue[100]!;
      case IncidentStatus.done:
        return Colors.green[100]!;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Hoy';
    } else if (diff.inDays == 1) {
      return 'Ayer';
    } else if (diff.inDays < 7) {
      return 'Hace ${diff.inDays} días';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
