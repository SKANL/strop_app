import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Service for compressing images before saving to reduce storage usage
class ImageCompressionService {
  /// Compress an image file
  ///
  /// - Quality: 80 (0-100, higher = better quality but larger file)
  /// - Max resolution: 1920px (maintains aspect ratio)
  /// - Target: < 5MB per image
  Future<File> compressImage(File imageFile) async {
    final directory = await getTemporaryDirectory();
    final targetPath = '${directory.path}/${const Uuid().v4()}.jpg';

    final result = await FlutterImageCompress.compressAndGetFile(
      imageFile.absolute.path,
      targetPath,
      quality: 80,
      minHeight: 1920,
    );

    if (result == null) {
      throw Exception('Failed to compress image');
    }

    return File(result.path);
  }

  /// Compress multiple images in parallel
  Future<List<File>> compressImages(List<File> imageFiles) async {
    final futures = imageFiles.map(compressImage).toList();
    return Future.wait(futures);
  }

  /// Get file size in MB
  Future<double> getFileSizeMB(File file) async {
    final bytes = await file.length();
    return bytes / (1024 * 1024);
  }
}
