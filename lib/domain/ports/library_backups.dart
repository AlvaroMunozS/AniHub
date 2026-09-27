import '../entities/entry.dart';
import '../errors/backup_format_exception.dart';

/// Library backups in the `anihub-library` format.
abstract interface class LibraryBackups {
  /// Lets the user pick a file and returns the entries it contains.
  ///
  /// Returns null if the user cancels. Throws a [BackupFormatException] if the
  /// file is not a valid library backup.
  Future<List<Entry>?> pickLibrary();

  /// Lets the user choose where to save [entries] and writes them there, as
  /// exported at [exportedAt].
  ///
  /// Returns false if the user cancels.
  Future<bool> saveLibrary(List<Entry> entries, {required DateTime exportedAt});
}
