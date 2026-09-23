import '../../domain/entities/entry.dart';
import '../../domain/ports/entry_repository.dart';
import '../../domain/values/watch_status.dart';

/// Sets whether an entry is a favorite.
///
/// Takes the target value rather than toggling, so repeated calls are
/// idempotent. Favoriting an entry that is not [WatchStatus.completed] also
/// completes it in the same write; unfavoriting leaves the status unchanged.
class SetFavorite {
  const SetFavorite(this._repository);

  final EntryRepository _repository;

  Future<Entry> call(Entry entry, {required bool isFavorite}) {
    final bool forceCompleted =
        isFavorite && entry.status != WatchStatus.completed;
    return _repository.save(
      entry.copyWith(
        isFavorite: isFavorite,
        status: forceCompleted ? WatchStatus.completed : entry.status,
      ),
    );
  }
}
