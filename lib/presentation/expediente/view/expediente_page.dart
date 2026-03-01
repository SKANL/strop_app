import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart'
    show
        BackButton,
        CircularProgressIndicator,
        Colors,
        Icons,
        InteractiveViewer,
        LinearProgressIndicator,
        Material,
        Navigator,
        PageRouteBuilder;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart'
    hide CircularProgressIndicator, Colors, LinearProgressIndicator;
import 'package:strop_app/app/di/service_locator.dart';
import 'package:strop_app/core/widgets/app_colors.dart';
import 'package:strop_app/core/widgets/strop_dialog.dart';
import 'package:strop_app/data/repositories/user_profile_repository.dart';
import 'package:strop_app/domain/entities/incident.dart';
import 'package:strop_app/domain/repositories/incident_repository.dart';
import 'package:url_launcher/url_launcher.dart';

class ExpedientePage extends StatefulWidget {
  const ExpedientePage({required this.incident, super.key});

  final Incident incident;

  @override
  State<ExpedientePage> createState() => _ExpedientePageState();
}

class _ExpedientePageState extends State<ExpedientePage> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isActionLoading = false;
  bool _canViewFinancials = true; // default true for backward compat
  bool _canCloseOperational = true; // default true — actual value loaded async

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
    _audioPlayer.onPositionChanged.listen((d) {
      if (mounted) setState(() => _position = d);
    });
    _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
    _loadCapabilities();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _toggleAudio() async {
    final path = widget.incident.audioPath;
    if (path == null) return;
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      if (_position > Duration.zero) {
        await _audioPlayer.resume();
      } else {
        if (path.startsWith('http')) {
          await _audioPlayer.play(UrlSource(path));
        } else {
          await _audioPlayer.play(DeviceFileSource(path));
        }
      }
    }
  }

  Future<void> _shareWhatsApp() async {
    final token = widget.incident.publicToken;
    if (token == null) {
      if (mounted) {
        showToast(
          context: context,
          builder: (ctx, overlay) => const Card(
            child: Text('Esta incidencia aún no tiene enlace público generado.'),
          ),
        );
      }
      return;
    }
    final message = Uri.encodeComponent(
      '🔧 Incidencia #${widget.incident.id.substring(0, 6).toUpperCase()}\n'
      '${widget.incident.description ?? ""}\n\n'
      '📍 ${widget.incident.specificLocation ?? widget.incident.location}\n\n'
      'Ver detalles y subir foto de resolución:\n'
      'https://constructora.zentyar.com/r/$token',
    );
    final uri = Uri.parse('https://wa.me/?text=$message');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // Fallback: open in browser if WhatsApp is not installed
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _loadCapabilities() async {
    final profile =
        await sl<UserProfileRepository>().getCurrentUserProfile();
    if (mounted) {
      setState(() {
        _canViewFinancials = profile?.can('financial.view_costs') ?? true;
        _canCloseOperational =
            profile?.can('incident.close_operational') ?? true;
      });
    }
  }

  Future<void> _changeStatus(
    IncidentStatus newStatus, {
    String? rejectionReason,
  }) async {
    setState(() => _isActionLoading = true);
    try {
      // Use the repository so local SQLite stays consistent and the
      // SyncService can retry if offline (instead of bypassing the repo).
      final updated = widget.incident.copyWith(
        status: newStatus,
        rejectionReason: rejectionReason,
      );
      await sl<IncidentRepository>().updateIncident(updated);
      if (mounted) {
        showToast(
          context: context,
          builder: (ctx, overlay) => Card(
            child: Text(_actionSuccessMessage(newStatus)),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        showToast(
          context: context,
          builder: (ctx, overlay) => Card(
            child: Text('Error: ${e.toString()}'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  String _statusToDbString(IncidentStatus status) => switch (status) {
    IncidentStatus.open => 'OPEN',
    IncidentStatus.inReview => 'IN_REVIEW',
    IncidentStatus.closed => 'CLOSED',
    IncidentStatus.rejected => 'REJECTED',
  };

  String _actionSuccessMessage(IncidentStatus status) => switch (status) {
    IncidentStatus.closed => '✅ Incidencia cerrada correctamente',
    IncidentStatus.rejected => '❌ Reparación rechazada',
    IncidentStatus.inReview => '🔄 Enviada a revisión',
    IncidentStatus.open => 'Incidencia reabierta',
  };

  Future<void> _showRejectDialog() async {
    final reason = await StropDialog.inputConfirm(
      context: context,
      title: 'Motivo de rechazo',
      hintText: 'Ej: Sigue goteando, mala mano de obra...',
      confirmLabel: 'Confirmar rechazo',
      isDestructive: true,
    );
    if (reason != null && mounted) {
      await _changeStatus(IncidentStatus.rejected, rejectionReason: reason);
    }
  }

  Widget _buildActionBar(Incident incident, ThemeData theme) {
    return switch (incident.status) {
      IncidentStatus.open => Row(
          children: [
            Expanded(
              child: Button(
                style: const ButtonStyle.outline(),
                onPressed: _shareWhatsApp,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.share_rounded, size: 16),
                    Gap(6),
                    Text('WhatsApp'),
                  ],
                ),
              ),
            ),
          ],
        ),
      IncidentStatus.inReview => _canCloseOperational
          ? Row(
              children: [
                Expanded(
                  child: Button(
                    style: const ButtonStyle.outline(),
                    onPressed: _showRejectDialog,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.close_rounded, size: 16),
                        Gap(4),
                        Text('Rechazar'),
                      ],
                    ),
                  ),
                ),
                const Gap(12),
                Expanded(
                  flex: 2,
                  child: Button(
                    style: const ButtonStyle.primary(),
                    onPressed: () => _changeStatus(IncidentStatus.closed),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_rounded, size: 16),
                        Gap(4),
                        Text('Aprobar y Cerrar'),
                      ],
                    ),
                  ),
                ),
              ],
            )
          // Read-only view: user can see IN_REVIEW but cannot close/reject
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.visibility_rounded,
                      size: 16, color: theme.colorScheme.mutedForeground),
                  const Gap(6),
                  Text(
                    'Pendiente de validación',
                    style: theme.typography.small.copyWith(
                      color: theme.colorScheme.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
      IncidentStatus.closed => const SizedBox.shrink(),
      IncidentStatus.rejected => _canCloseOperational
          ? Row(
              children: [
                Expanded(
                  child: Button(
                    style: const ButtonStyle.outline(),
                    onPressed: () => _changeStatus(IncidentStatus.open),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.refresh_rounded, size: 16),
                        Gap(4),
                        Text('Reabrir'),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : const SizedBox.shrink(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final incident = widget.incident;
    final theme = Theme.of(context);
    final dateStr =
        DateFormat('dd MMM yyyy, HH:mm', 'es').format(incident.createdAt);

    return Scaffold(
      headers: [
        AppBar(
          title: const Text('Expediente'),
          leading: [const BackButton()],
        ),
      ],
      footers: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          decoration: BoxDecoration(
            color: theme.colorScheme.card,
            border: Border(
              top: BorderSide(color: theme.colorScheme.border),
            ),
          ),
          child: _isActionLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildActionBar(incident, theme),
        ),
      ],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header Card ───────────────────────────────────────────────
            Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              incident.title,
                              style: theme.typography.h3,
                            ),
                            const Gap(4),
                            Row(
                              children: [
                                Text(
                                  '#${incident.id.substring(0, 6).toUpperCase()}',
                                  style: theme.typography.small.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                const Gap(8),
                                Text(
                                  dateStr,
                                  style: theme.typography.small.copyWith(
                                    color: theme.colorScheme.mutedForeground,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      _StatusChip(status: incident.status),
                    ],
                  ),
                  const Gap(8),
                  Row(
                    children: [
                      _PriorityChip(priority: incident.priority),
                      const Gap(8),
                      if (!incident.isSynced)
                        _SyncPendingChip(),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 200.ms),

            const Gap(16),

            // ── Photos Section ────────────────────────────────────────────
            if (incident.photos.isNotEmpty) ...[
              Text('Evidencia fotográfica', style: theme.typography.h4),
              const Gap(8),
              SizedBox(
                height: 200,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: incident.photos.length,
                  separatorBuilder: (_, __) => const Gap(8),
                  itemBuilder: (context, index) {
                    final photoPath = incident.photos[index];
                    return GestureDetector(
                      onTap: () => _showFullscreenPhoto(context, photoPath),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _buildPhoto(photoPath, 200, 200),
                      ),
                    );
                  },
                ),
              ),
              const Gap(16),
            ],

            // ── Audio Section ─────────────────────────────────────────────
            if (incident.audioPath != null) ...[
              Text('Nota de voz', style: theme.typography.h4),
              const Gap(8),
              Card(
                child: Row(
                  children: [
                    IconButton(
                      variance: ButtonVariance.primary,
                      icon: Icon(
                        _isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                      onPressed: _toggleAudio,
                    ),
                    const Gap(12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LinearProgressIndicator(
                            value: _duration.inMilliseconds > 0
                                ? _position.inMilliseconds /
                                    _duration.inMilliseconds
                                : 0,
                          ),
                          const Gap(4),
                          Text(
                            '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                            style: theme.typography.small.copyWith(
                              color: theme.colorScheme.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Gap(8),
                  ],
                ),
              ),
              const Gap(16),
            ],

            // ── Details Section ───────────────────────────────────────────
            Text('Detalles', style: theme.typography.h4),
            const Gap(8),
            Card(
              child: Column(
                children: [
                  if (incident.description != null)
                    _DetailRow(
                      label: 'Descripción',
                      value: incident.description!,
                    ),
                  _DetailRow(
                    label: 'Proyecto',
                    value: incident.location,
                  ),
                  if (incident.specificLocation != null)
                    _DetailRow(
                      label: 'Ubicación específica',
                      value: incident.specificLocation!,
                    ),
                  if (incident.assignedTrade != null)
                    _DetailRow(
                      label: 'Gremio',
                      value: _tradeLabel(incident.assignedTrade!),
                    ),
                ],
              ),
            ),
            const Gap(16),

            // ── Financial Section ─────────────────────────────────────────
            if (_canViewFinancials && incident.estimatedCost != null) ...[
              Text('Información Financiera', style: theme.typography.h4),
              const Gap(8),
              Card(
                child: Column(
                  children: [
                    _DetailRow(
                      label: 'Costo estimado',
                      value:
                          '\$${incident.estimatedCost!.toStringAsFixed(2)}',
                    ),
                    _DetailRow(
                      label: 'Cobrable al contratista',
                      value: incident.isBillable ? 'Sí' : 'No',
                    ),
                  ],
                ),
              ),
              const Gap(16),
            ],

            // ── Assigned to ───────────────────────────────────────────────
            if (incident.assignedTo != null) ...[
              Card(
                child: _DetailRow(
                  label: 'Asignado a',
                  value: incident.assignedTo!,
                ),
              ),
              const Gap(16),
            ],

            // ── Rejection Section ─────────────────────────────────────────
            if (incident.status == IncidentStatus.rejected &&
                incident.rejectionReason != null) ...[
              Card(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.cancel_rounded,
                      color: AppColors.error,
                      size: 20,
                    ),
                    const Gap(12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Motivo de rechazo',
                            style: theme.typography.small.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Gap(4),
                          Text(
                            incident.rejectionReason!,
                            style: theme.typography.p,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(16),
            ],


          ],
        ),
      ),
    );
  }

  Widget _buildPhoto(String path, double width, double height) {
    if (path.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: path,
        width: width,
        height: height,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          color: Colors.grey[200],
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (_, __, ___) => Container(
          color: Colors.grey[200],
          child: const Icon(Icons.broken_image_rounded, size: 32),
        ),
      );
    }
    return Image.file(
      File(path),
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: Colors.grey[200],
        child: const Icon(Icons.broken_image_rounded, size: 32),
      ),
    );
  }

  void _showFullscreenPhoto(BuildContext context, String path) {
    Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        opaque: false,
        pageBuilder: (ctx, _, __) => Material(
          color: Colors.black87,
          child: Stack(
            fit: StackFit.expand,
            children: [
              InteractiveViewer(
                child: _buildPhoto(path, double.infinity, double.infinity),
              ),
              Positioned(
                top: 48,
                right: 16,
                child: IconButton(
                  variance: ButtonVariance.ghost,
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ],
          ),
        ),
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

// ── Helper Widgets ─────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final IncidentStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = switch (status) {
      IncidentStatus.open => (
          AppColors.statusPending.withValues(alpha: 0.15),
          AppColors.statusPending,
          'Abierta',
        ),
      IncidentStatus.inReview => (
          AppColors.statusInReview.withValues(alpha: 0.15),
          AppColors.statusInReview,
          'En Revisión',
        ),
      IncidentStatus.closed => (
          AppColors.statusDone.withValues(alpha: 0.15),
          AppColors.statusDone,
          'Cerrada',
        ),
      IncidentStatus.rejected => (
          AppColors.error.withValues(alpha: 0.15),
          AppColors.error,
          'Rechazada',
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  const _PriorityChip({required this.priority});
  final IncidentPriority priority;

  @override
  Widget build(BuildContext context) {
    final (bg, label) = switch (priority) {
      IncidentPriority.critical => (AppColors.priorityCritical, 'CRÍTICA'),
      IncidentPriority.urgent => (AppColors.priorityUrgent, 'URGENTE'),
      IncidentPriority.normal => (AppColors.priorityNormal, 'NORMAL'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          color: Colors.white,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _SyncPendingChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.syncPending.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_upload_outlined,
              size: 12, color: AppColors.syncPending),
          const Gap(4),
          Text(
            'Sin sincronizar',
            style: TextStyle(
              fontSize: 10,
              color: AppColors.syncPending,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: theme.typography.small.copyWith(
                color: theme.colorScheme.mutedForeground,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: theme.typography.p),
          ),
        ],
      ),
    );
  }
}
