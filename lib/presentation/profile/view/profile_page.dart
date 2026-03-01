import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strop_app/app/di/service_locator.dart';
import 'package:strop_app/core/network/connectivity_service.dart';
import 'package:strop_app/core/services/cache_service.dart';
import 'package:strop_app/core/widgets/strop_dialog.dart';
import 'package:strop_app/domain/entities/incident.dart';
import 'package:strop_app/domain/repositories/auth_repository.dart';
import 'package:strop_app/domain/repositories/incident_repository.dart';
import 'package:strop_app/domain/repositories/user_repository.dart';
import 'package:strop_app/presentation/auth/bloc/auth_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  Future<void> _logout(BuildContext context) async {
    final pendingCount = await sl<IncidentRepository>()
        .getPendingIncidentCount();

    if (!context.mounted) return;

    if (pendingCount > 0) {
      final confirmed = await StropDialog.confirm(
        context: context,
        title: 'Datos sin sincronizar',
        body:
            'Tienes $pendingCount registros sin sincronizar. '
            'Si cierras sesión ahora se perderán permanentemente.',
        confirmLabel: 'Cerrar Sesión',
        cancelLabel: 'Cancelar',
        isDestructive: true,
      );
      if (confirmed != true) return;
    }
    // pendingCount == 0 → log out directly, no confirmation needed.

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
    final user = context.read<AuthBloc>().state.user;
    final displayName = (user.name?.isNotEmpty ?? false)
        ? user.name!
        : user.email.split('@').first;
    final theme = Theme.of(context);

    return Scaffold(
      headers: [
        AppBar(title: const Text('Perfil')),
      ],
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── User header card ─────────────────────────────────────────────
          Card(
            child: Row(
              children: [
                Semantics(
                  label: 'Avatar de usuario',
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      displayName.isNotEmpty
                          ? displayName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: theme.typography.p.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        user.email,
                        style: theme.typography.small.copyWith(
                          color: theme.colorScheme.mutedForeground,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Sync Hub ─────────────────────────────────────────────────────
          Text('Estado de Sincronización', style: theme.typography.h4),
          const SizedBox(height: 12),
          const SyncHub(),
          const SizedBox(height: 24),

          // ── Storage & Data ────────────────────────────────────────────────
          Text('Almacenamiento y Datos', style: theme.typography.h4),
          const SizedBox(height: 12),
          const CacheManagementTile(),
          const SizedBox(height: 10),
          const OfflineSettingsTile(),
          const SizedBox(height: 24),

          // ── Support ──────────────────────────────────────────────────────
          Text('Soporte', style: theme.typography.h4),
          const SizedBox(height: 12),
          _SupportTile(onTap: () => _openWhatsApp(context)),
          const SizedBox(height: 24),

          // ── Sign Out ─────────────────────────────────────────────────────
          Button(
            style: const ButtonStyle.outline(),
            onPressed: () => _logout(context),
            child: const Center(child: Text('Cerrar Sesión')),
          ),
          const SizedBox(height: 24),

          // ── App version (dynamic) ─────────────────────────────────────────
          const _AppVersionText(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Support Tile — replaces Material ListTile
// ─────────────────────────────────────────────────────────────────────────────

class _SupportTile extends StatelessWidget {
  const _SupportTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Color(0xFFdcfce7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.support_agent_rounded,
                  size: 20,
                  color: Color(0xFF15803D),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Contactar Soporte',
                      style: theme.typography.p.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Chatea con nosotros por WhatsApp',
                      style: theme.typography.small.copyWith(
                        color: theme.colorScheme.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: theme.colorScheme.mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SyncHub
class SyncHub extends StatefulWidget {
  const SyncHub({super.key});

  @override
  State<SyncHub> createState() => _SyncHubState();
}

class _SyncHubState extends State<SyncHub> {
  bool _isSyncing = false;
  bool _isOnline = true;
  int _pendingPhotos = 0;
  StreamSubscription<bool>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    _isOnline = true;
    unawaited(_fetchPhotoCounts());
    _connectivitySub = sl<ConnectivityService>().onConnectivityChanged.listen((
      online,
    ) {
      if (mounted) setState(() => _isOnline = online);
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  Future<void> _fetchPhotoCounts() async {
    try {
      final status = await sl<UserRepository>().getSyncStatus();
      if (mounted) {
        setState(() {
          _pendingPhotos = (status['pendingPhotos'] as int?) ?? 0;
        });
      }
    } on Exception {
      // best-effort
    }
  }

  Future<void> _sync() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    try {
      await sl<IncidentRepository>().syncPendingIncidents();
      await _fetchPhotoCounts();
      if (mounted) {
        showToast(
          context: context,
          builder: (context, overlay) => const Card(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_done_rounded,
                  color: Color(0xFF16a34a),
                  size: 18,
                ),
                SizedBox(width: 8),
                Text('Sincronización completada'),
              ],
            ),
          ),
        );
      }
    } on Exception catch (e) {
      if (mounted) {
        showToast(
          context: context,
          builder: (context, overlay) => Card(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Color(0xFFB91C1C),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text('Error: $e')),
              ],
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  ({Color color, IconData icon, String label}) _statusInfo(
    int pending,
    int errors,
  ) {
    if (_isSyncing) {
      return (
        color: const Color(0xFF2563EB),
        icon: Icons.sync_rounded,
        label: 'Sincronizando...',
      );
    }
    if (errors > 0) {
      return (
        color: const Color(0xFFB91C1C),
        icon: Icons.warning_amber_rounded,
        label: 'Error de Subida',
      );
    }
    if (pending > 0 && !_isOnline) {
      return (
        color: const Color(0xFFf97316),
        icon: Icons.cloud_off_rounded,
        label: 'Esperando Conexión',
      );
    }
    if (pending > 0) {
      return (
        color: const Color(0xFFf97316),
        icon: Icons.cloud_upload_rounded,
        label: 'Pendiente de Sincronizar',
      );
    }
    return (
      color: const Color(0xFF16a34a),
      icon: Icons.cloud_done_rounded,
      label: 'Todo Sincronizado',
    );
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
        final status = _statusInfo(pending, errors);

        return Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Status indicator ──────────────────────────────────────
              Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: status.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(status.icon, size: 16, color: status.color),
                  const SizedBox(width: 6),
                  Text(
                    status.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: status.color,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Queue detail ────────────────────────────────────────
              if (pending > 0 || _pendingPhotos > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    '${pending > 0 ? '$pending incidencia${pending > 1 ? 's' : ''}' : ''}'
                    '${pending > 0 && _pendingPhotos > 0 ? ', ' : ''}'
                    '${_pendingPhotos > 0 ? '$_pendingPhotos foto${_pendingPhotos > 1 ? 's' : ''}' : ''}'
                    ' pendiente${(pending + _pendingPhotos) > 1 ? 's' : ''} de subir',
                    style: TextStyle(
                      fontSize: 12,
                      color: status.color,
                    ),
                  ),
                ),

              // ── Stats row ───────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatItem(label: 'Total', value: total.toString()),
                  _StatItem(
                    label: 'Pendientes',
                    value: pending.toString(),
                    isWarning: pending > 0,
                  ),
                  _StatItem(
                    label: 'Errores',
                    value: errors.toString(),
                    isWarning: errors > 0,
                    color: errors > 0 ? const Color(0xFFB91C1C) : null,
                  ),
                ],
              ),

              // ── Item-level queue ────────────────────────────────────
              if (pending > 0 || errors > 0) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 8),
                ...incidents
                    .where((i) =>
                        i.syncStatus == SyncStatus.pending ||
                        i.syncStatus == SyncStatus.error)
                    .take(6)
                    .map((i) {
                  final isPending = i.syncStatus == SyncStatus.pending;
                  final isError = i.syncStatus == SyncStatus.error;
                  final icon = isError
                      ? Icons.error_outline_rounded
                      : _isSyncing
                          ? Icons.upload_rounded
                          : Icons.hourglass_top_rounded;
                  final color = isError
                      ? const Color(0xFFB91C1C)
                      : _isSyncing
                          ? const Color(0xFF2563EB)
                          : const Color(0xFFf97316);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(icon, size: 14, color: color),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            i.description?.isNotEmpty == true
                                ? i.description!
                                : 'Incidencia sin descripción',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isError ? 'Error' : (isPending ? 'Pendiente' : ''),
                            style: TextStyle(
                                fontSize: 10,
                                color: color,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                if (pending + errors > 6)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '+ ${pending + errors - 6} más...',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF9CA3AF)),
                    ),
                  ),
                const SizedBox(height: 4),
              ],

              // ── Progress bar (while syncing) ────────────────────────
              if (_isSyncing) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],

              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Button(
                      style: const ButtonStyle.primary(),
                      onPressed:
                          _isSyncing ||
                              ((pending == 0 && errors == 0) && !_isOnline) ||
                              (!_isSyncing && pending == 0 && errors == 0)
                          ? null
                          : _sync,
                      child: _isSyncing
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.bolt_rounded, size: 18),
                                SizedBox(width: 6),
                                Text('Forzar Sincronización'),
                              ],
                            ),
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
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color ?? (isWarning ? const Color(0xFFf97316) : null),
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
      showToast(
        context: context,
        builder: (context, overlay) => const Card(
          child: Text('No puedes limpiar la caché con cargas pendientes.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    await sl<CacheService>().clearCache();
    await _loadCacheSize();

    if (mounted) {
      showToast(
        context: context,
        builder: (context, overlay) =>
            const Card(child: Text('Caché limpiada correctamente')),
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
    final theme = Theme.of(context);
    return Card(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Caché local',
                style: theme.typography.p.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (_isLoading)
                const SizedBox(
                  height: 12,
                  width: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Text(
                  _formatSize(_cacheSize),
                  style: theme.typography.small.copyWith(
                    color: theme.colorScheme.mutedForeground,
                  ),
                ),
            ],
          ),
          Button(
            style: const ButtonStyle.ghost(),
            onPressed: _isLoading || _cacheSize == 0 ? null : _clearCache,
            child: const Text('Limpiar'),
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
    final theme = Theme.of(context);
    return Card(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Descarga automática de medios',
                  style: theme.typography.p.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Descargar fotos del proyecto por WiFi',
                  style: theme.typography.small.copyWith(
                    color: theme.colorScheme.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: _autoDownload,
            onChanged: _toggleSetting,
          ),
        ],
      ),
    );
  }
}

/// Shows the app version read dynamically from the platform.
class _AppVersionText extends StatefulWidget {
  const _AppVersionText();

  @override
  State<_AppVersionText> createState() => _AppVersionTextState();
}

class _AppVersionTextState extends State<_AppVersionText> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    unawaited(
      PackageInfo.fromPlatform().then((info) {
        if (mounted) {
          setState(() {
            _version = 'v${info.version} (build ${info.buildNumber})';
          });
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_version.isEmpty) return const SizedBox.shrink();
    return Center(
      child: Text(
        _version,
        style: Theme.of(context).typography.small.copyWith(
          color: Theme.of(context).colorScheme.mutedForeground,
        ),
      ),
    );
  }
}
