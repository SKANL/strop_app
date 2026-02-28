import 'dart:io';

import 'package:flutter/material.dart' show showModalBottomSheet;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:strop_app/app/di/service_locator.dart';
import 'package:strop_app/core/widgets/app_colors.dart';
import 'package:strop_app/domain/entities/incident.dart';
import 'package:strop_app/presentation/inbox/bloc/inbox_bloc.dart';
import 'package:strop_app/presentation/inbox/bloc/inbox_event.dart';
import 'package:strop_app/presentation/inbox/bloc/inbox_state.dart';

class InboxPage extends StatelessWidget {
  const InboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => sl<InboxBloc>()..add(SubscribeToIncidents()),
      child: const InboxView(),
    );
  }
}

class InboxView extends StatefulWidget {
  const InboxView({super.key});

  @override
  State<InboxView> createState() => _InboxViewState();
}

class _InboxViewState extends State<InboxView> {
  int _tabIndex = 0;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  void _onTabChanged(int index) {
    setState(() => _tabIndex = index);
    final status = switch (index) {
      0 => IncidentStatus.pending,
      1 => IncidentStatus.inReview,
      2 => IncidentStatus.done,
      _ => IncidentStatus.pending,
    };
    context.read<InboxBloc>().add(ChangeTab(status));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      headers: [
        // ── App Bar ────────────────────────────────────────────────────────
        AppBar(
          title: const Text('Bandeja'),
          trailing: [
            Semantics(
              label: _isSearching ? 'Cerrar búsqueda' : 'Buscar',
              button: true,
              excludeSemantics: true,
              child: IconButton(
                variance: ButtonVariance.ghost,
                icon: Icon(
                  _isSearching ? Icons.close_rounded : Icons.search_rounded,
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    if (_isSearching) {
                      _isSearching = false;
                      _searchController.clear();
                      context
                          .read<InboxBloc>()
                          .add(const SearchIncidents(''));
                    } else {
                      _isSearching = true;
                    }
                  });
                },
              ),
            ),
          ],
        ),

        // ── Collapsible search bar ─────────────────────────────────────────
        if (_isSearching)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              placeholder: const Text('Buscar incidencias…'),
              onChanged: (value) =>
                  context.read<InboxBloc>().add(SearchIncidents(value)),
            ),
          ),

        // ── Status tabs ────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Tabs(
            index: _tabIndex,
            onChanged: _onTabChanged,
            expand: true,
            children: [
              TabItem(child: const Text('Pendientes', style: TextStyle(fontSize: 11))),
              TabItem(child: const Text('En Revisión', style: TextStyle(fontSize: 11))),
              TabItem(child: const Text('Cerradas', style: TextStyle(fontSize: 11))),
            ],
          ),
        ),
        const Gap(4),
      ],
      child: BlocBuilder<InboxBloc, InboxState>(
        builder: (context, state) {
          if (state is InboxLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is InboxError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 48,
                    color: Theme.of(context).colorScheme.destructive,
                  ),
                  const Gap(16),
                  Text(
                    'Error: ${state.message}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.mutedForeground,
                    ),
                  ),
                ],
              ),
            );
          }

          if (state is InboxLoaded) {
            final incidents = state.incidents;

            if (incidents.isEmpty) {
              return _EmptyState(
                isSearch: state.searchQuery.isNotEmpty,
                query: state.searchQuery,
                tab: state.currentTab,
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              itemCount: incidents.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final incident = incidents[index];
                return _IncidentItem(incident: incident)
                    .animate(delay: (40 * index).ms)
                    .fadeIn();
              },
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty State
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.isSearch,
    required this.query,
    required this.tab,
  });

  final bool isSearch;
  final String query;
  final IncidentStatus tab;

  String _tabLabel() => switch (tab) {
        IncidentStatus.pending => 'pendientes',
        IncidentStatus.inReview => 'en revisión',
        IncidentStatus.done => 'cerradas',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                color: theme.colorScheme.muted,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSearch ? Icons.search_off_rounded : Icons.construction_rounded,
                size: 40,
                color: theme.colorScheme.mutedForeground,
              ),
            ),
            const Gap(20),
            Text(
              isSearch
                  ? 'Sin resultados para "$query"'
                  : 'Sin incidencias ${_tabLabel()}',
              style: theme.typography.p.copyWith(
                color: theme.colorScheme.mutedForeground,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            if (!isSearch) ...[
              const Gap(8),
              Text(
                'Usa el botón de cámara para registrar una incidencia.',
                style: theme.typography.small.copyWith(
                  color: theme.colorScheme.mutedForeground,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Incident Item — swipeable card
// ─────────────────────────────────────────────────────────────────────────────

class _IncidentItem extends StatefulWidget {
  const _IncidentItem({required this.incident});

  final Incident incident;

  @override
  State<_IncidentItem> createState() => _IncidentItemState();
}

class _IncidentItemState extends State<_IncidentItem> {
  void _updateStatus(BuildContext context, IncidentStatus newStatus) {
    context.read<InboxBloc>().add(
          UpdateIncidentStatus(widget.incident, newStatus),
        );

    showToast(
      context: context,
      builder: (context, overlay) => Card(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded,
                color: AppColors.success, size: 18),
            const SizedBox(width: 8),
            Text(
              'Movida a ${_statusLabel(newStatus)}',
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  void _delete(BuildContext context) {
    context.read<InboxBloc>().add(DeleteIncident(widget.incident));

    showToast(
      context: context,
      builder: (toastCtx, overlay) => Card(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.delete_outline_rounded, size: 16,
                color: AppColors.statusPending),
            const SizedBox(width: 8),
            const Text('Incidencia eliminada', style: TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }

  String _statusLabel(IncidentStatus status) => switch (status) {
        IncidentStatus.pending => 'Pendientes',
        IncidentStatus.inReview => 'En Revisión',
        IncidentStatus.done => 'Cerradas',
      };

  @override
  Widget build(BuildContext context) {
    return Slidable(
      key: Key(widget.incident.id),
      startActionPane: ActionPane(
        motion: const DrawerMotion(),
        children: [
          if (widget.incident.status != IncidentStatus.done)
            SlidableAction(
              onPressed: (_) {
                final nextStatus =
                    widget.incident.status == IncidentStatus.pending
                        ? IncidentStatus.inReview
                        : IncidentStatus.done;
                _updateStatus(context, nextStatus);
              },
              backgroundColor: AppColors.statusDone,
              foregroundColor: Colors.white,
              icon: Icons.check_rounded,
              label: widget.incident.status == IncidentStatus.pending
                  ? 'Revisar'
                  : 'Cerrar',
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(8),
              ),
            ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => _delete(context),
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
            icon: Icons.delete_outline_rounded,
            label: 'Eliminar',
            borderRadius: const BorderRadius.horizontal(
              right: Radius.circular(8),
            ),
          ),
        ],
      ),
      child: Card(
        padding: const EdgeInsets.all(12),
        child: GestureDetector(
          onTap: () {
            _IncidentDetailSheet.show(context, widget.incident);
          },
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Priority accent stripe ───────────────────────────────
              Container(
                width: 3,
                height: 64,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: _priorityColor(widget.incident.priority),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // ── Photo thumbnail ──────────────────────────────────────
              if (widget.incident.photos.isNotEmpty) ...[              
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: _PhotoThumbnail(
                      path: widget.incident.photos.first,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.incident.title,
                      style: Theme.of(context).typography.p.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    if (widget.incident.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.incident.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).typography.small.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .mutedForeground,
                            ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          size: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .mutedForeground,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            widget.incident.location,
                            style: Theme.of(context).typography.small.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .mutedForeground,
                                  fontSize: 11,
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _SyncStatusIcon(status: widget.incident.syncStatus),
                      const SizedBox(width: 6),
                      _PriorityBadge(priority: widget.incident.priority),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatDate(widget.incident.createdAt),
                    style: Theme.of(context).typography.small.copyWith(
                          fontSize: 11,
                          color: Theme.of(context)
                              .colorScheme
                              .mutedForeground,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _priorityColor(IncidentPriority priority) => switch (priority) {
        IncidentPriority.critical => AppColors.priorityCritical,
        IncidentPriority.urgent => AppColors.priorityUrgent,
        IncidentPriority.normal => AppColors.priorityNormal,
      };

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Hoy';
    if (diff.inDays == 1) return 'Ayer';
    return 'Hace ${diff.inDays}d';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Photo thumbnail — shows the first photo of an incident, or a placeholder
// ─────────────────────────────────────────────────────────────────────────────

class _PhotoThumbnail extends StatelessWidget {
  const _PhotoThumbnail({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final file = File(path);
    if (file.existsSync()) {
      return Image.file(file, fit: BoxFit.cover);
    }
    return Container(
      color: Theme.of(context).colorScheme.muted,
      child: Icon(
        Icons.image_not_supported_rounded,
        size: 24,
        color: Theme.of(context).colorScheme.mutedForeground,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sync status icon — pulsing animation when pending upload
// ─────────────────────────────────────────────────────────────────────────────

class _SyncStatusIcon extends StatelessWidget {
  const _SyncStatusIcon({required this.status});

  final SyncStatus status;

  @override
  Widget build(BuildContext context) {
    final icon = switch (status) {
      SyncStatus.pending => Semantics(
          label: 'Pendiente de sincronización',
          child: const Icon(
            Icons.cloud_upload_outlined,
            color: AppColors.syncPending,
            size: 18,
          )
              .animate(onPlay: (c) => c.repeat())
              .fadeOut(duration: 750.ms, curve: Curves.easeInOut)
              .then()
              .fadeIn(duration: 750.ms, curve: Curves.easeInOut),
        ),
      SyncStatus.synced => Semantics(
          label: 'Sincronizado',
          child: const Icon(Icons.cloud_done_rounded,
              color: AppColors.success, size: 18),
        ),
      SyncStatus.error => Semantics(
          label: 'Error de sincronización',
          child: const Icon(Icons.error_outline_rounded,
              color: AppColors.error, size: 18),
        ),
      SyncStatus.syncing => Semantics(
          label: 'Sincronizando',
          child: const Icon(Icons.sync_rounded,
              color: AppColors.statusInReview, size: 18),
        ),
    };
    return icon;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Priority badge — WCAG AA compliant (solid bg, white text, ≥4.5:1)
// ─────────────────────────────────────────────────────────────────────────────

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});

  final IncidentPriority priority;

  @override
  Widget build(BuildContext context) {
    final (bg, label) = switch (priority) {
      IncidentPriority.critical => (AppColors.priorityCritical, 'CRÍTICO'),
      IncidentPriority.urgent => (AppColors.priorityUrgent, 'URGENTE'),
      IncidentPriority.normal => (AppColors.priorityNormal, 'NORMAL'),
    };

    return Semantics(
      label: 'Prioridad: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Incident detail bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _IncidentDetailSheet extends StatelessWidget {
  const _IncidentDetailSheet({
    required this.incident,
    required this.bloc,
  });

  final Incident incident;
  final InboxBloc bloc;

  static void show(BuildContext context, Incident incident) {
    final bloc = context.read<InboxBloc>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => BlocProvider.value(
        value: bloc,
        child: _IncidentDetailSheet(incident: incident, bloc: bloc),
      ),
    );
  }

  void _updateStatus(BuildContext context, IncidentStatus newStatus) {
    context.read<InboxBloc>().add(UpdateIncidentStatus(incident, newStatus));
    Navigator.of(context).pop();
    showToast(
      context: context,
      builder: (ctx, overlay) => Card(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded,
                color: AppColors.success, size: 18),
            const SizedBox(width: 8),
            Text(
              'Movida a ${_statusLabel(newStatus)}',
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  void _delete(BuildContext context) {
    context.read<InboxBloc>().add(DeleteIncident(incident));
    Navigator.of(context).pop();
    showToast(
      context: context,
      builder: (ctx, overlay) => const Card(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline_rounded,
                size: 16, color: AppColors.statusPending),
            SizedBox(width: 8),
            Text('Incidencia eliminada', style: TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }

  String _statusLabel(IncidentStatus status) => switch (status) {
        IncidentStatus.pending => 'Pendientes',
        IncidentStatus.inReview => 'En Revisión',
        IncidentStatus.done => 'Cerradas',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nextStatus = switch (incident.status) {
      IncidentStatus.pending => IncidentStatus.inReview,
      IncidentStatus.inReview => IncidentStatus.done,
      IncidentStatus.done => null,
    };

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 12,
        left: 16,
        right: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Badges row
            Row(
              children: [
                _StatusChip(status: incident.status),
                const SizedBox(width: 8),
                _PriorityBadge(priority: incident.priority),
                const Spacer(),
                _SyncStatusIcon(status: incident.syncStatus),
              ],
            ),
            const SizedBox(height: 14),

            // Title
            Text(
              incident.title,
              style: theme.typography.p.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),

            // Description
            if (incident.description != null &&
                incident.description!.isNotEmpty) ...[  
              const SizedBox(height: 8),
              Text(
                incident.description!,
                style: theme.typography.small.copyWith(
                  color: theme.colorScheme.mutedForeground,
                ),
              ),
            ],
            const SizedBox(height: 12),

            // Photos
            if (incident.photos.isNotEmpty)
              SizedBox(
                height: 120,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: incident.photos.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 120,
                      height: 120,
                      child: _PhotoThumbnail(path: incident.photos[i]),
                    ),
                  ),
                ),
              ),
            if (incident.photos.isNotEmpty) const SizedBox(height: 12),

            // Meta row: location, date, trade
            Row(
              children: [
                Icon(Icons.location_on_rounded,
                    size: 14,
                    color: theme.colorScheme.mutedForeground),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    [
                      incident.location,
                      if (incident.specificLocation != null)
                        incident.specificLocation!,
                    ].join(' • '),
                    style: theme.typography.small.copyWith(
                      color: theme.colorScheme.mutedForeground,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.schedule_rounded,
                    size: 14,
                    color: theme.colorScheme.mutedForeground),
                const SizedBox(width: 4),
                Text(
                  _formatDate(incident.createdAt),
                  style: theme.typography.small.copyWith(
                    color: theme.colorScheme.mutedForeground,
                  ),
                ),
                if (incident.assignedTrade != null) ...[  
                  const SizedBox(width: 12),
                  Icon(Icons.construction_rounded,
                      size: 14, color: theme.colorScheme.mutedForeground),
                  const SizedBox(width: 4),
                  Text(
                    incident.assignedTrade!.name,
                    style: theme.typography.small.copyWith(
                      color: theme.colorScheme.mutedForeground,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),

            // Actions
            if (nextStatus != null)
              SizedBox(
                width: double.infinity,
                child: Button(
                  style: const ButtonStyle.primary(),
                  onPressed: () => _updateStatus(context, nextStatus),
                  child: Text(
                    nextStatus == IncidentStatus.inReview
                        ? 'Pasar a En Revisión'
                        : 'Cerrar Incidencia',
                  ),
                ),
              ),
            if (nextStatus != null) const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: Button(
                style: const ButtonStyle.destructive(),
                onPressed: () => _delete(context),
                child: const Text('Eliminar incidencia'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Hoy';
    if (diff.inDays == 1) return 'Ayer';
    return 'Hace ${diff.inDays}d';
  }
}

// Status chip used inside the detail sheet
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final IncidentStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, label) = switch (status) {
      IncidentStatus.pending =>
        (AppColors.statusPending.withValues(alpha: 0.15), 'Pendiente'),
      IncidentStatus.inReview =>
        (AppColors.statusInReview.withValues(alpha: 0.15), 'En Revisión'),
      IncidentStatus.done =>
        (AppColors.statusDone.withValues(alpha: 0.15), 'Cerrada'),
    };
    final textColor = switch (status) {
      IncidentStatus.pending => AppColors.statusPending,
      IncidentStatus.inReview => AppColors.statusInReview,
      IncidentStatus.done => AppColors.statusDone,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
