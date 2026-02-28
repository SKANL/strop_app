import 'dart:async';
import 'dart:io';

import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:strop_app/core/app_notifiers.dart';
import 'package:strop_app/core/widgets/app_colors.dart';
import 'package:strop_app/core/widgets/strop_dialog.dart';
import 'package:strop_app/presentation/capture/view/annotation_page.dart';
import 'package:strop_app/presentation/capture/view/incident_form_page.dart';
import 'package:strop_app/presentation/capture/view/permissions_gate_page.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    required this.navigationShell,
    super.key,
  });

  final StatefulNavigationShell navigationShell;

  Future<void> _goBranch(BuildContext context, int index) async {
    if (index == navigationShell.currentIndex) {
      return;
    }

    if (index == 2) {
      // Camera: check permissions first, then open capture overlay.
      final ctx =
          navigationShell.shellRouteContext.navigatorKey.currentContext;
      if (ctx == null) return;

      final granted = await PermissionsGatePage.ensureGranted(ctx);
      if (!granted || !ctx.mounted) return;

      final files = await ctx.push<List<XFile>>('/camera');

      if (files != null && files.isNotEmpty && ctx.mounted) {
        final imageFiles = files.map((xFile) => File(xFile.path)).toList();

        await Navigator.of(ctx).push(
          MaterialPageRoute<void>(
            builder: (ctx2) => AnnotationPage(
              imageFiles: imageFiles,
              onNext: (annotatedImages) {
                unawaited(
                  Navigator.of(ctx2).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          IncidentFormPage(imageFiles: annotatedImages),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      }
      return;
    }

    // ── Guard: active capture form ─────────────────────────────────────────
    // IncidentFormPage (and AnnotationPage) are pushed imperatively onto the
    // shell's navigator via MaterialPageRoute.  StatefulShellRoute.indexedStack
    // keeps every branch alive in memory, so switching branches does NOT pop
    // those pages — they remain on the navigator stack and reappear when the
    // user returns to the original branch (or float above other branches).
    // Solution: intercept tab switches while the form is active and ask the
    // user whether they want to discard the unsaved incident.
    if (IncidentFormPage.isFormActive.value) {
      if (!context.mounted) return;
      final discard = await StropDialog.confirm(
        context: context,
        title: '¿Descartar incidencia?',
        body: 'Tienes una incidencia sin guardar. '
            'Si cambias de pantalla, las fotos y los datos se perderán.',
        confirmLabel: 'Descartar',
        cancelLabel: 'Seguir editando',
        isDestructive: true,
      );
      if (discard != true || !context.mounted) return;

      // Pop all imperatively-pushed pages (IncidentFormPage + AnnotationPage)
      IncidentFormPage.isFormActive.value = false;
      final shellCtx =
          navigationShell.shellRouteContext.navigatorKey.currentContext;
      if (shellCtx != null && shellCtx.mounted) {
        Navigator.of(shellCtx).popUntil((route) => route.isFirst);
      }
    }
    // ───────────────────────────────────────────────────────────────────────

    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      child: navigationShell,
      footers: [
        _StropBottomNav(
          currentIndex: navigationShell.currentIndex,
          onTap: (i) => _goBranch(context, i),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom shadcn-styled bottom navigation
// ─────────────────────────────────────────────────────────────────────────────

class _StropBottomNav extends StatelessWidget {
  const _StropBottomNav({
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.card,
        border: Border(
          top: BorderSide(color: theme.colorScheme.border),
        ),
      ),
      padding: EdgeInsets.fromLTRB(4, 8, 4, safeBottom + 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            icon: Icons.home_rounded,
            label: 'Proyectos',
            selected: currentIndex == 0,
            onTap: () => onTap(0),
          ),
          _NavItem(
            icon: Icons.inbox_rounded,
            label: 'Bandeja',
            selected: currentIndex == 1,
            onTap: () => onTap(1),
            badge: ValueListenableBuilder<int>(
              valueListenable: AppNotifiers.syncPendingCount,
              builder: (_, count, __) => count > 0
                  ? Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.syncPending,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        constraints:
                            const BoxConstraints(minWidth: 16, minHeight: 14),
                        child: Text(
                          '$count',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
          _CameraNavButton(onTap: () => onTap(2)),
          _NavItem(
            icon: Icons.person_rounded,
            label: 'Perfil',
            selected: currentIndex == 3,
            onTap: () => onTap(3),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  /// Optional overlay widget positioned top-right of the icon pill (e.g. a
  /// pending-sync count badge). Rendered with a [Stack] only when provided.
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.mutedForeground;

    final iconPill = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: selected
            ? theme.colorScheme.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, size: 22, color: color),
    );

    return Expanded(
      child: Semantics(
        selected: selected,
        label: label,
        button: true,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (badge != null)
                Stack(clipBehavior: Clip.none, children: [iconPill, badge!])
              else
                iconPill,
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The primary capture action — elevated FAB button in the centre of the nav.
class _CameraNavButton extends StatelessWidget {
  const _CameraNavButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Semantics(
        label: 'Capturar incidencia',
        button: true,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              )
                  .animate(
                    onPlay: (c) => c.repeat(reverse: true),
                  )
                  .shimmer(
                    duration: 3.seconds,
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
              const SizedBox(height: 2),
              Text(
                'Capturar',
                style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
