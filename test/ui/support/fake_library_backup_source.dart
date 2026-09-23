import 'package:anihub/domain/entities/entry.dart';
import 'package:anihub/domain/ports/library_backup_source.dart';

/// Returns [entries], or throws [error] when set. With both null it acts as
/// a cancelled file pick.
class FakeLibraryBackupSource implements LibraryBackupSource {
  const FakeLibraryBackupSource({this.entries, this.error});

  final List<Entry>? entries;
  final Object? error;

  @override
  Future<List<Entry>?> pickLibrary() async {
    if (error != null) {
      throw error!;
    }
    return entries;
  }
}
