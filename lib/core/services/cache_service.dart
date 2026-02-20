import 'dart:developer' as developer;
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class CacheService {
  /// Returns the total size of the temporary and application support
  /// directories in bytes.
  Future<int> getCacheSize() async {
    var totalSize = 0;
    try {
      final tempDir = await getTemporaryDirectory();
      final appDir = await getApplicationSupportDirectory();

      totalSize += await _getDirSize(tempDir);
      totalSize += await _getDirSize(appDir);
    } on Exception catch (e) {
      developer.log('Error calculating cache size', error: e);
    }
    return totalSize;
  }

  /// Clears the temporary directory and specific cache folders.
  ///
  /// Note: In a real app, we would selectively delete files based on
  /// whether they are associated with synced incidents.
  /// For this MVP, we are just clearing the temporary directory.
  Future<void> clearCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      _deleteDirContent(tempDir);
    } on Exception catch (e) {
      developer.log('Error clearing cache', error: e);
    }
  }

  Future<int> _getDirSize(Directory dir) async {
    var size = 0;
    try {
      if (dir.existsSync()) {
        await for (final file in dir.list(
          recursive: true,
          followLinks: false,
        )) {
          if (file is File) {
            size += file.lengthSync();
          }
        }
      }
    } on Exception catch (e) {
      developer.log(
        'Error calculating directory size for ${dir.path}',
        error: e,
      );
    }
    return size;
  }

  void _deleteDirContent(Directory dir) {
    try {
      if (dir.existsSync()) {
        final entities = dir.listSync(followLinks: false);
        for (final file in entities) {
          try {
            file.deleteSync(recursive: true);
          } on Exception catch (e) {
            developer.log('Error deleting file ${file.path}', error: e);
          }
        }
      }
    } on Exception catch (e) {
      developer.log('Error clearing directory ${dir.path}', error: e);
    }
  }
}
