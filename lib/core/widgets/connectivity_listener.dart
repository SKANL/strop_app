import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:strop_app/app/di/service_locator.dart';
import 'package:strop_app/core/network/connectivity_service.dart';

class ConnectivityListener extends StatefulWidget {
  const ConnectivityListener({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  State<ConnectivityListener> createState() => _ConnectivityListenerState();
}

class _ConnectivityListenerState extends State<ConnectivityListener> {
  StreamSubscription<bool>? _subscription;
  bool? _lastConnectionState;

  @override
  void initState() {
    super.initState();
    _subscription = sl<ConnectivityService>().onConnectivityChanged.listen(
      (isConnected) {
        if (_lastConnectionState != isConnected) {
          _lastConnectionState = isConnected;
          _showToast(isConnected);
        }
      },
    );
  }

  void _showToast(bool isConnected) {
    if (!mounted) return;

    if (isConnected) {
      shadcn.showToast(
        context: context,
        builder: (context, overlay) => const shadcn.Card(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi, color: Colors.green, size: 20),
              SizedBox(width: 8),
              Text('Connection restored'),
            ],
          ),
        ),
      );
    } else {
      shadcn.showToast(
        context: context,
        builder: (context, overlay) => const shadcn.Card(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off, color: Colors.orange, size: 20),
              SizedBox(width: 8),
              Text('You are offline'),
            ],
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
