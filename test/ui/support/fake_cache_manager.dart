import 'dart:typed_data';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';

/// A transparent 1x1 PNG.
final Uint8List _png = Uint8List.fromList(const <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// [BaseCacheManager] that serves a 1x1 PNG from an in-memory file system
/// for every URL, or fails when [fail] is set. Records the requested URLs.
class FakeCacheManager extends Fake implements BaseCacheManager {
  FakeCacheManager({this.fail = false});

  final bool fail;
  final List<String> requested = <String>[];

  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) async* {
    requested.add(url);
    if (fail) {
      throw const HttpExceptionWithStatus(404, 'not found');
    }
    final file = await MemoryCacheSystem().createFile('cover.png');
    await file.writeAsBytes(_png);
    yield FileInfo(
      file,
      FileSource.Cache,
      DateTime.now().add(const Duration(days: 365)),
      url,
    );
  }
}
