import 'package:anihub/domain/entities/entry.dart';
import 'package:anihub/domain/ports/library_backups.dart';

/// Picks [entries], or throws [error] when set; with both null the pick is
/// cancelled. Saving records what it is given and returns [saveResult], or
/// throws [saveError] when set.
class FakeLibraryBackups implements LibraryBackups {
  FakeLibraryBackups({
    this.entries,
    this.error,
    this.saveResult = false,
    this.saveError,
  });

  final List<Entry>? entries;
  final Object? error;
  final bool saveResult;
  final Object? saveError;

  /// The entries of the last [saveLibrary] call, or null if none was made.
  List<Entry>? savedEntries;
  DateTime? savedAt;

  @override
  Future<List<Entry>?> pickLibrary() async {
    if (error != null) {
      throw error!;
    }
    return entries;
  }

  @override
  Future<bool> saveLibrary(
    List<Entry> entries, {
    required DateTime exportedAt,
  }) async {
    savedEntries = entries;
    savedAt = exportedAt;
    if (saveError != null) {
      throw saveError!;
    }
    return saveResult;
  }
}
