import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:strop_app/presentation/capture/view/annotation_page.dart';
import 'package:strop_app/presentation/capture/view/incident_form_page.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    required this.navigationShell,
    super.key,
  });

  final StatefulNavigationShell navigationShell;

  Future<void> _goBranch(int index) async {
    if (index == 2) {
      final context =
          navigationShell.shellRouteContext.navigatorKey.currentContext;
      if (context == null) return;

      final files = await context.push<List<XFile>>('/camera');

      if (files != null && files.isNotEmpty && context.mounted) {
        // Convert XFiles to Files
        final imageFiles = files.map((xFile) => File(xFile.path)).toList();

        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => AnnotationPage(
              imageFiles: imageFiles,
              onNext: (annotatedImages) {
                unawaited(
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => IncidentFormPage(
                        imageFiles: annotatedImages,
                      ),
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
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        onTap: _goBranch,
        currentIndex: navigationShell.currentIndex,
        type: BottomNavigationBarType.fixed,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.inbox),
            label: 'Inbox',
          ),
          BottomNavigationBarItem(
            icon: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(12),
              child: const Icon(
                Icons.camera_alt,
                color: Colors.white,
              ),
            ),
            label: 'Capture',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
