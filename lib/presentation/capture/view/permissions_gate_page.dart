import 'dart:async';

import 'package:flutter/material.dart' show Colors;
import 'package:permission_handler/permission_handler.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Colors;

/// Shown the first time the user tries to start the capture flow
/// when camera or location permissions have not been granted.
///
/// The caller awaits the returned [Future<bool>]: `true` means all
/// required permissions were granted and the flow can continue.
class PermissionsGatePage extends StatefulWidget {
  const PermissionsGatePage({super.key});

  /// Request camera + location permissions and, if already granted,
  /// return immediately without pushing the page.
  static Future<bool> ensureGranted(BuildContext context) async {
    final camera = await Permission.camera.status;
    final location = await Permission.locationWhenInUse.status;

    if (camera.isGranted && location.isGranted) return true;

    if (!context.mounted) return false;
    final result = await Navigator.of(context).push<bool>(
      PageRouteBuilder<bool>(
        pageBuilder: (_, __, ___) => const PermissionsGatePage(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
    return result ?? false;
  }

  @override
  State<PermissionsGatePage> createState() => _PermissionsGatePageState();
}

class _PermissionsGatePageState extends State<PermissionsGatePage> {
  bool _requesting = false;

  Future<void> _requestPermissions() async {
    setState(() => _requesting = true);

    final results = await [
      Permission.camera,
      Permission.locationWhenInUse,
    ].request();

    if (!mounted) return;
    setState(() => _requesting = false);

    final cameraGranted = results[Permission.camera]?.isGranted ?? false;
    final locationGranted =
        results[Permission.locationWhenInUse]?.isGranted ?? false;

    if (cameraGranted && locationGranted) {
      Navigator.of(context).pop(true);
    } else if (!cameraGranted || !locationGranted) {
      // At least one denied — show guidance to open settings
      final openSettings =
          await _showPermanentlyDeniedDialog(context);
      if (openSettings == true) {
        unawaited(openAppSettings());
      }
    }
  }

  static Future<bool?> _showPermanentlyDeniedDialog(
      BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Permisos requeridos'),
        content: const Text(
          'Cámara y ubicación son necesarias para capturar incidencias. '
          'Por favor habilítalos desde Configuración.',
        ),
        actions: [
          Button(
            style: const ButtonStyle.ghost(),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Ahora no'),
          ),
          Button(
            style: const ButtonStyle.primary(),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Abrir Configuración'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.camera_alt_outlined,
                  size: 44,
                  color: theme.colorScheme.primary,
                ),
              ),
              const Gap(24),

              // Title
              Text(
                'Permisos necesarios',
                style: theme.typography.h3,
                textAlign: TextAlign.center,
              ),
              const Gap(12),

              // Body
              Text(
                'Para capturar incidencias, Strop necesita acceso a tu cámara y ubicación.\n\n'
                '• Cámara — para fotografiar la incidencia.\n'
                '• Ubicación — para detectar el proyecto cercano automáticamente.',
                style: theme.typography.p.copyWith(
                  color: theme.colorScheme.mutedForeground,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const Gap(40),

              // CTA
              SizedBox(
                width: double.infinity,
                child: Button(
                  style: const ButtonStyle.primary(),
                  onPressed: _requesting ? null : _requestPermissions,
                  child: _requesting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Conceder permisos'),
                ),
              ),
              const Gap(12),

              // Skip
              Button(
                style: const ButtonStyle.ghost(),
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Ahora no',
                  style: TextStyle(
                    color: theme.colorScheme.mutedForeground,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
