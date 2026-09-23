import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../../domain/ports/image_cache_storage.dart';

/// [ImageCacheStorage] over the `flutter_cache_manager` cache that stores its
/// files in [_directory].
class CacheManagerImageCacheStorage implements ImageCacheStorage {
  CacheManagerImageCacheStorage(this._cacheManager, this._directory);

  final BaseCacheManager _cacheManager;
  final Directory _directory;

  @override
  Future<int> sizeInBytes() async {
    if (!await _directory.exists()) return 0;
    int total = 0;
    await for (final FileSystemEntity entity in _directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) continue;
      try {
        total += await entity.length();
      } on FileSystemException {
        // The cache manager evicts files at any time, so one listed a moment
        // ago may already be gone.
      }
    }
    return total;
  }

  @override
  Future<void> clear() async {
    await _cacheManager.emptyCache();
    // Decoded covers stay in memory and would still show until evicted.
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
  }
}
