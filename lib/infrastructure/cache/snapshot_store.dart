/// Persistent slot for a single serialized snapshot.
abstract interface class SnapshotStore {
  /// Returns the last written snapshot, or null if none exists.
  ///
  /// Synchronous so that cached data can be served at startup without waiting
  /// on storage.
  String? read();

  /// Replaces the stored snapshot with [json].
  Future<void> write(String json);
}
