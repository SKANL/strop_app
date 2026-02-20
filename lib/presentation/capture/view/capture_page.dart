import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:strop_app/presentation/capture/view/annotation_page.dart';
import 'package:strop_app/presentation/capture/view/incident_form_page.dart'; // Import // Import

class CapturePage extends StatefulWidget {
  const CapturePage({super.key});

  @override
  State<CapturePage> createState() => _CapturePageState();
}

class _CapturePageState extends State<CapturePage> {
  List<File> _images = [];

  Future<void> _pickImage() async {
    try {
      final photos = await context.push<List<XFile>>('/camera');

      if (photos != null && photos.isNotEmpty) {
        setState(() {
          _images = photos.map((xFile) => File(xFile.path)).toList();
        });
      }
    } on Exception catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        shadcn.showToast(
          context: context,
          builder: (context, overlay) => shadcn.Card(
            child: Row(
              children: [
                const Icon(Icons.error, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(child: Text('Could not capture image: $e')),
              ],
            ),
          ),
        );
      }
    }
  }

  void _retake() {
    setState(() {
      _images = [];
    });
    unawaited(_pickImage());
  }

  void _next() {
    if (_images.isEmpty) return;

    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => AnnotationPage(
            imageFiles: _images,
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_images.isNotEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Show first image as preview
            Image.file(
              _images.first,
              fit: BoxFit.contain,
            ),
            // Photo counter badge
            if (_images.length > 1)
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${_images.length} photos',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  shadcn.Button.outline(
                    onPressed: _retake,
                    child: const Text('Retake'),
                  ),
                  shadcn.Button.primary(
                    onPressed: _next,
                    child: const Text('Use Photos'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt, size: 64, color: Colors.grey),
            const SizedBox(height: 20),
            const Text('No image captured'),
            const SizedBox(height: 20),
            shadcn.Button.primary(
              onPressed: _pickImage,
              child: const Text('Open Camera'),
            ),
          ],
        ),
      ),
    );
  }
}
