import 'package:anihub/domain/ports/image_cache_storage.dart';

/// Holds [size] bytes until cleared, or fails to measure or clear when the
/// matching error is set. Counts the calls to [clear].
class FakeImageCacheStorage implements ImageCacheStorage {
  FakeImageCacheStorage({this.size = 0, this.sizeError, this.clearError});

  int size;
  final Object? sizeError;
  final Object? clearError;
  int clears = 0;

  @override
  Future<int> sizeInBytes() async {
    if (sizeError != null) throw sizeError!;
    return size;
  }

  @override
  Future<void> clear() async {
    clears++;
    if (clearError != null) throw clearError!;
    size = 0;
  }
}
