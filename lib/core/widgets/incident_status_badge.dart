import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:strop_app/core/widgets/app_colors.dart';
import 'package:strop_app/domain/entities/incident.dart';

/// Shared pill badge for incident status — used in Bandeja and ProjectDashboard.
class IncidentStatusBadge extends StatelessWidget {
  const IncidentStatusBadge({required this.status, super.key});

  final IncidentStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (label, bg, fg) = switch (status) {
      IncidentStatus.open => (
          'Pendiente',
          theme.colorScheme.muted,
          theme.colorScheme.mutedForeground
        ),
      IncidentStatus.inReview => (
          'En Revisión',
          AppColors.statusInReview.withValues(alpha: 0.12),
          AppColors.statusInReview,
        ),
      IncidentStatus.closed => (
          'Completado',
          AppColors.statusDone.withValues(alpha: 0.12),
          AppColors.statusDone,
        ),
      IncidentStatus.rejected => (
          'Rechazado',
          AppColors.error.withValues(alpha: 0.12),
          AppColors.error,
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
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}
