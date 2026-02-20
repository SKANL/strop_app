import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strop_app/app/di/service_locator.dart';
import 'package:strop_app/core/services/cache_service.dart';
import 'package:strop_app/domain/entities/incident.dart';
import 'package:strop_app/domain/repositories/auth_repository.dart';
import 'package:strop_app/domain/repositories/incident_repository.dart';
import 'package:strop_app/presentation/auth/bloc/auth_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  Future<void> _logout(BuildContext context) async {
    final pendingCount = await sl<IncidentRepository>()
        .getPendingIncidentCount();

    if (!context.mounted) return;

    if (pendingCount > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return shadcn.AlertDialog(
            title: const Text('Warning: Unsynced Data'),
            content: Text(
              'You have $pendingCount unsynced items. '
              'Logging out now will delete them permanently.',
            ),
            actions: [
              shadcn.Button.ghost(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              shadcn.Button.destructive(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Logout Anyway'),
              ),
            ],
          );
        },
      );
      if (confirmed != true) return;
    } else {
      // Standard confirmation if no pending data
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return shadcn.AlertDialog(
            title: const Text('Confirm Logout'),
            content: const Text('Are you sure you want to log out?'),
            actions: [
              shadcn.Button.ghost(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              shadcn.Button.destructive(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Logout'),
              ),
            ],
          );
        },
      );
      if (confirmed != true) return;
    }

    if (context.mounted) {
      await sl<AuthRepository>().logOut();
      if (context.mounted) {
        context.go('/login');
      }
    }
  }

  Future<void> _openWhatsApp(BuildContext context) async {
    final user = context.read<AuthBloc>().state.user;
    final uri = Uri.parse(
      'https://wa.me/5219999999999?text=Hi, I need help with the Strop App (User ID: ${user.id})',
    );
    if (!await launchUrl(uri)) {
      developer.log('Could not launch WhatsApp');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // User Header
          Center(
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.grey,
                  child: Icon(Icons.person, size: 40, color: Colors.white),
                ),
                const SizedBox(height: 16),
                Text(
                  'Field Worker',
                  style: shadcn.Theme.of(context).typography.h4,
                ),
                Text(
                  context.read<AuthBloc>().state.user.email,
                  style: shadcn.Theme.of(context).typography.small.copyWith(
                    color: shadcn.Theme.of(context).colorScheme.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Sync Hub
          Text('Sync Status', style: shadcn.Theme.of(context).typography.h4),
          const SizedBox(height: 16),
          const SyncHub(),

          const SizedBox(height: 32),

          // Storage & Data
          Text('Storage & Data', style: shadcn.Theme.of(context).typography.h4),
          const SizedBox(height: 16),
          const CacheManagementTile(),
          const SizedBox(height: 12),
          const OfflineSettingsTile(),

          const SizedBox(height: 32),

          // Support
          Text('Support', style: shadcn.Theme.of(context).typography.h4),
          const SizedBox(height: 16),
          shadcn.Card(
            child: ListTile(
              leading: const Icon(Icons.help_outline, color: Colors.green),
              title: const Text('Contact Support'),
              subtitle: const Text('Chat with us on WhatsApp'),
              onTap: () => _openWhatsApp(context),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),

          const SizedBox(height: 32),

          // Logout
          shadcn.Button.outline(
            onPressed: () => _logout(context),
            child: const Center(child: Text('Logout')),
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              'Version 1.0.0 (Build 240)',
              style: shadcn.Theme.of(context).typography.small.copyWith(
                color: shadcn.Theme.of(context).colorScheme.mutedForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SyncHub extends StatefulWidget {
  const SyncHub({super.key});

  @override
  State<SyncHub> createState() => _SyncHubState();
}

class _SyncHubState extends State<SyncHub> {
  bool _isSyncing = false;

  Future<void> _sync() async {
    if (_isSyncing) return;

    setState(() {
      _isSyncing = true;
    });

    try {
      await sl<IncidentRepository>().syncPendingIncidents();
      if (mounted) {
        shadcn.showToast(
          context: context,
          builder: (context, overlay) =>
              const shadcn.Card(child: Text('Sync completed')),
        );
      }
    } on Exception catch (e) {
      if (mounted) {
        shadcn.showToast(
          context: context,
          builder: (context, overlay) =>
              shadcn.Card(child: Text('Sync failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Incident>>(
      stream: sl<IncidentRepository>().incidentsStream,
      builder: (context, snapshot) {
        final incidents = snapshot.data ?? [];
        final total = incidents.length;
        final pending = incidents
            .where((i) => i.syncStatus == SyncStatus.pending)
            .length;
        final errors = incidents
            .where((i) => i.syncStatus == SyncStatus.error)
            .length;

        return shadcn.Card(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatItem(
                    label: 'Total',
                    value: total.toString(),
                  ),
                  _StatItem(
                    label: 'Pending',
                    value: pending.toString(),
                    isWarning: pending > 0,
                  ),
                  _StatItem(
                    label: 'Errors',
                    value: errors.toString(),
                    isWarning: errors > 0,
                    color: errors > 0 ? Colors.red : null,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: shadcn.Button.primary(
                      onPressed: _isSyncing || pending == 0 ? null : _sync,
                      child: _isSyncing
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Sync Now'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    this.isWarning = false,
    this.color,
  });

  final String label;
  final String value;
  final bool isWarning;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = shadcn.Theme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color ?? (isWarning ? Colors.orange : null),
          ),
        ),
        Text(
          label,
          style: theme.typography.small.copyWith(
            color: theme.colorScheme.mutedForeground,
          ),
        ),
      ],
    );
  }
}

class CacheManagementTile extends StatefulWidget {
  const CacheManagementTile({super.key});

  @override
  State<CacheManagementTile> createState() => _CacheManagementTileState();
}

class _CacheManagementTileState extends State<CacheManagementTile> {
  int _cacheSize = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadCacheSize());
  }

  Future<void> _loadCacheSize() async {
    final size = await sl<CacheService>().getCacheSize();
    if (mounted) {
      setState(() {
        _cacheSize = size;
        _isLoading = false;
      });
    }
  }

  Future<void> _clearCache() async {
    final pendingCount = await sl<IncidentRepository>()
        .getPendingIncidentCount();
    if (pendingCount > 0) {
      if (!mounted) return;
      shadcn.showToast(
        context: context,
        builder: (context, overlay) => const shadcn.Card(
          child: Text('Cannot clear cache while you have pending uploads.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    await sl<CacheService>().clearCache();
    await _loadCacheSize();

    if (mounted) {
      shadcn.showToast(
        context: context,
        builder: (context, overlay) =>
            const shadcn.Card(child: Text('Cache cleared')),
      );
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return shadcn.Card(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Local Cache'),
                  if (_isLoading)
                    const SizedBox(
                      height: 12,
                      width: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Text(
                      _formatSize(_cacheSize),
                      style: shadcn.Theme.of(context).typography.small.copyWith(
                        color: shadcn.Theme.of(
                          context,
                        ).colorScheme.mutedForeground,
                      ),
                    ),
                ],
              ),
              shadcn.Button.ghost(
                onPressed: _isLoading || _cacheSize == 0 ? null : _clearCache,
                child: const Text('Clear'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class OfflineSettingsTile extends StatefulWidget {
  const OfflineSettingsTile({super.key});

  @override
  State<OfflineSettingsTile> createState() => _OfflineSettingsTileState();
}

class _OfflineSettingsTileState extends State<OfflineSettingsTile> {
  bool _autoDownload = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSettings());
  }

  Future<void> _loadSettings() async {
    final prefs = sl<SharedPreferences>();
    if (mounted) {
      setState(() {
        _autoDownload = prefs.getBool('auto_download_media') ?? true;
      });
    }
  }

  Future<void> _toggleSetting(bool value) async {
    final prefs = sl<SharedPreferences>();
    await prefs.setBool('auto_download_media', value);
    if (mounted) {
      setState(() {
        _autoDownload = value;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return shadcn.Card(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Auto-download Media'),
              Text(
                'Download project photos over WiFi',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          shadcn.Switch(
            value: _autoDownload,
            onChanged: _toggleSetting,
          ),
        ],
      ),
    );
  }
}
