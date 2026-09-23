/// The covers kept on the device so they load instantly and offline.
abstract interface class ImageCacheStorage {
  /// Returns the disk space the cached covers take, in bytes.
  Future<int> sizeInBytes();

  /// Deletes the cached covers from disk and memory. They are downloaded
  /// again when they are next shown.
  Future<void> clear();
}
