import '../../domain/entities/entry.dart';
import '../../domain/ports/entry_repository.dart';
import '../../domain/values/watch_status.dart';

/// Sets the watch status of an entry.
///
/// Any transition is allowed. Moving an entry out of [WatchStatus.completed]
/// also clears its favorite flag (see [Entry.withStatus]).
class ChangeStatus {
  const ChangeStatus(this._repository);

  final EntryRepository _repository;

  Future<Entry> call(Entry entry, WatchStatus status) {
    return _repository.save(entry.withStatus(status));
  }
}
