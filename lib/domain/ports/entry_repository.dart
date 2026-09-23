import '../entities/entry.dart';

/// Persistence for the user's library.
abstract interface class EntryRepository {
  /// Returns every entry, most recently updated first.
  Future<List<Entry>> findAll();

  /// Inserts [entry] if its `id` is null, or updates it otherwise.
  ///
  /// Returns the persisted entry, with `id` and `updatedAt` assigned by the
  /// repository.
  Future<Entry> save(Entry entry);

  /// Deletes the entry with [id]. Does nothing if there is none.
  Future<void> delete(String id);

  /// Emits the full library, in the order of [findAll], on subscription and
  /// after every change.
  Stream<List<Entry>> watchAll();

  /// Inserts or updates [entries] in a single operation, keeping each
  /// `updatedAt` as given.
  ///
  /// Unlike [save], which always stamps the current time, this preserves the
  /// timestamps that an import compares to decide which copy is newer.
  Future<void> upsertAll(List<Entry> entries);
}
