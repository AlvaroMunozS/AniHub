import '../../domain/entities/entry.dart';
import '../../domain/ports/entry_repository.dart';
import '../../domain/ports/library_backups.dart';

/// Saves the whole library, in every status, as a backup file.
class ExportLibrary {
  const ExportLibrary(this._repository, this._backups);

  final EntryRepository _repository;
  final LibraryBackups _backups;

  /// Returns the number of entries saved, or null if the user cancels.
  ///
  /// An empty library returns 0 without asking where to save it, since the
  /// file would restore nothing.
  Future<int?> call(DateTime exportedAt) async {
    final List<Entry> entries = await _repository.findAll();
    if (entries.isEmpty) {
      return 0;
    }
    final bool saved = await _backups.saveLibrary(
      entries,
      exportedAt: exportedAt,
    );
    return saved ? entries.length : null;
  }
}
