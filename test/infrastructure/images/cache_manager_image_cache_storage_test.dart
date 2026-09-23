import 'dart:async';
import 'dart:io';

import 'package:anihub/infrastructure/images/cache_manager_image_cache_storage.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingCacheManager extends Fake implements BaseCacheManager {
  int emptied = 0;

  @override
  Future<void> emptyCache() async => emptied++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('anihub_images_test');
    addTearDown(() => root.delete(recursive: true));
  });

  test('adds up the files in the cache folder and its subfolders', () async {
    final Directory cache = Directory('${root.path}/anihubImages');
    await Directory('${cache.path}/nested').create(recursive: true);
    await File('${cache.path}/a.jpg').writeAsBytes(List<int>.filled(300, 0));
    await File('${cache.path}/nested/b.jpg')
        .writeAsBytes(List<int>.filled(45, 0));

    final CacheManagerImageCacheStorage storage = CacheManagerImageCacheStorage(
      _RecordingCacheManager(),
      cache,
    );

    expect(await storage.sizeInBytes(), 345);
  });

  test('measures a missing cache folder as empty', () async {
    final CacheManagerImageCacheStorage storage = CacheManagerImageCacheStorage(
      _RecordingCacheManager(),
      Directory('${root.path}/missing'),
    );

    expect(await storage.sizeInBytes(), 0);
  });

  test('empties the disk cache and the decoded images', () async {
    final _RecordingCacheManager manager = _RecordingCacheManager();
    final ImageCache images = PaintingBinding.instance.imageCache;
    images.putIfAbsent(
      'cover',
      () => OneFrameImageStreamCompleter(Completer<ImageInfo>().future),
    );
    expect(images.containsKey('cover'), isTrue);

    await CacheManagerImageCacheStorage(manager, root).clear();

    expect(manager.emptied, 1);
    expect(images.containsKey('cover'), isFalse);
  });
}
