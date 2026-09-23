import '../entities/entry.dart';
import '../errors/backup_format_exception.dart';

/// Source of library backups in the `anihub-library` format.
abstract interface class LibraryBackupSource {
  /// Lets the user pick a file and returns the entries it contains.
  ///
  /// Returns null if the user cancels. Throws a [BackupFormatException] if the
  /// file is not a valid library backup.
  Future<List<Entry>?> pickLibrary();
}
