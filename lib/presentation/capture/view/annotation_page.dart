import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_painter/image_painter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:strop_app/core/widgets/step_progress_bar.dart';
import 'package:uuid/uuid.dart';

class AnnotationPage extends StatefulWidget {
  const AnnotationPage({
    required this.imageFiles,
    required this.onNext,
    super.key,
  });

  final List<File> imageFiles;
  final ValueChanged<List<File>> onNext;

  @override
  State<AnnotationPage> createState() => _AnnotationPageState();
}

class _AnnotationPageState extends State<AnnotationPage> {
  late final List<ImagePainterController> _controllers;
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      widget.imageFiles.length,
      (_) => ImagePainterController(
        strokeWidth: 5,
      ),
    );
    _pageController = PageController();
  }

  @override
  void dispose() {
    // Don't dispose controllers here to avoid "used after being disposed" error
    // The controllers will be garbage collected when the widget is removed
    super.dispose();
  }

  Future<void> _done() async {
    final annotatedFiles = <File>[];

    for (var i = 0; i < _controllers.length; i++) {
      final imageBytes = await _controllers[i].exportImage();
      if (imageBytes == null) {
        // If export fails, use original image
        annotatedFiles.add(widget.imageFiles[i]);
        continue;
      }

      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/${const Uuid().v4()}.png';
      final file = File(path);
      await file.writeAsBytes(imageBytes);
      annotatedFiles.add(file);
    }

    widget.onNext(annotatedFiles);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'Anotar (${_currentPage + 1}/${widget.imageFiles.length})',
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _done,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: StepProgressBar(current: 2, total: 3),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.imageFiles.length,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemBuilder: (context, index) {
                return _KeepAliveWrapper(
                  child: ImagePainter.file(
                    widget.imageFiles[index],
                    controller: _controllers[index],
                    scalable: true,
                  ),
                );
              },
            ),
          ),
          // Page Indicator
          if (widget.imageFiles.length > 1)
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.imageFiles.length,
                  (index) => Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentPage == index
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _KeepAliveWrapper extends StatefulWidget {
  const _KeepAliveWrapper({required this.child});

  final Widget child;

  @override
  State<_KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<_KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
