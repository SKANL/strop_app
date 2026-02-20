import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:strop_app/app/di/service_locator.dart';
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

class _InboxViewState extends State<InboxView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      final status = switch (_tabController.index) {
        0 => IncidentStatus.pending,
        1 => IncidentStatus.inReview,
        2 => IncidentStatus.done,
        _ => IncidentStatus.pending,
      };
      context.read<InboxBloc>().add(ChangeTab(status));
    }
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search incidents...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white70),
                ),
                style: const TextStyle(color: Colors.white),
                onChanged: (value) {
                  context.read<InboxBloc>().add(SearchIncidents(value));
                },
              )
            : const Text('Inbox'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchController.clear();
                  context.read<InboxBloc>().add(const SearchIncidents(''));
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Review'),
            Tab(text: 'Closed'),
          ],
        ),
      ),
      body: BlocBuilder<InboxBloc, InboxState>(
        builder: (context, state) {
          if (state is InboxLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is InboxError) {
            return Center(child: Text('Error: ${state.message}'));
          }

          if (state is InboxLoaded) {
            final incidents = state.incidents;

            if (incidents.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.check_box_outline_blank,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      state.searchQuery.isEmpty
                          ? 'No ${state.currentTab.name.replaceAll(
                              RegExp('(?<!^)(?=[A-Z])'),
                              ' ',
                            ).toLowerCase()} incidents'
                          : 'No results found',
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              itemCount: incidents.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final incident = incidents[index];
                return _IncidentItem(incident: incident);
              },
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _IncidentItem extends StatelessWidget {
  const _IncidentItem({required this.incident});

  final Incident incident;

  void _updateStatus(BuildContext context, IncidentStatus newStatus) {
    context.read<InboxBloc>().add(UpdateIncidentStatus(incident, newStatus));

    // Show toast feedback
    shadcn.showToast(
      context: context,
      builder: (context, overlay) => shadcn.Card(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 20),
            const SizedBox(width: 8),
            Text('Moved to ${newStatus.name}'),
          ],
        ),
      ),
    );
  }

  void _delete(BuildContext context) {
    context.read<InboxBloc>().add(DeleteIncident(incident));
  }

  @override
  Widget build(BuildContext context) {
    return Slidable(
      key: Key(incident.id),
      startActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          if (incident.status != IncidentStatus.done)
            SlidableAction(
              onPressed: (_) {
                final nextStatus = incident.status == IncidentStatus.pending
                    ? IncidentStatus.inReview
                    : IncidentStatus.done;
                _updateStatus(context, nextStatus);
              },
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              icon: Icons.check,
              label: incident.status == IncidentStatus.pending
                  ? 'Review'
                  : 'Close',
            ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          /*
          SlidableAction(
            onPressed: (_) {
              // TODO(user): Implement more options
            },
            backgroundColor: Colors.grey,
            foregroundColor: Colors.white,
            icon: Icons.more_horiz,
            label: 'More',
          ),
          */
          SlidableAction(
            onPressed: (_) => _delete(context),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: 'Delete',
          ),
        ],
      ),
      child: shadcn.Card(
        padding: const EdgeInsets.all(12),
        child: InkWell(
          onTap: () {
            // Navigate to details
          },
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      incident.title,
                      style: shadcn.Theme.of(context).typography.p.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (incident.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        incident.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: shadcn.Theme.of(context).typography.small
                            .copyWith(
                              color: shadcn.Theme.of(
                                context,
                              ).colorScheme.mutedForeground,
                            ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 14,
                          color: shadcn.Theme.of(
                            context,
                          ).colorScheme.mutedForeground,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            incident.location,
                            style: shadcn.Theme.of(context).typography.small
                                .copyWith(
                                  color: shadcn.Theme.of(
                                    context,
                                  ).colorScheme.mutedForeground,
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
                      _SyncStatusIcon(status: incident.syncStatus),
                      const SizedBox(width: 8),
                      _PriorityBadge(priority: incident.priority),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatDate(incident.createdAt),
                    style: shadcn.Theme.of(
                      context,
                    ).typography.small.copyWith(fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }
}

class _SyncStatusIcon extends StatelessWidget {
  const _SyncStatusIcon({required this.status});

  final SyncStatus status;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      SyncStatus.pending => const Icon(
        Icons.cloud_upload_outlined,
        color: Colors.orange,
        size: 18,
      ),
      SyncStatus.synced => const Icon(
        Icons.cloud_done,
        color: Colors.green,
        size: 18,
      ),
      SyncStatus.error => const Icon(
        Icons.error_outline,
        color: Colors.red,
        size: 18,
      ),
      SyncStatus.syncing => const Icon(
        Icons.sync,
        color: Colors.blue,
        size: 18,
      ),
    };
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});

  final IncidentPriority priority;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (priority) {
      IncidentPriority.critical => (Colors.red, 'CRITICAL'),
      IncidentPriority.urgent => (Colors.orange, 'URGENT'),
      IncidentPriority.normal => (Colors.blue, 'NORMAL'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
