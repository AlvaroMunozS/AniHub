import '../../domain/entities/catalog_anime.dart';
import '../../domain/entities/entry.dart';
import '../../domain/errors/duplicate_entry_exception.dart';
import '../../domain/ports/entry_repository.dart';
import '../../domain/values/watch_status.dart';

/// Adds a catalog anime to the library.
///
/// A favorite is always stored as [WatchStatus.completed], whatever [status]
/// is passed (see [Entry.withFavorite]).
///
/// Throws a [DuplicateEntryException] without writing anything if an entry
/// with the same `malId` already exists, as reported by
/// [EntryRepository.save].
class AddEntry {
  const AddEntry(this._repository);

  final EntryRepository _repository;

  Future<Entry> call(
    CatalogAnime anime, {
    WatchStatus status = WatchStatus.planned,
    bool isFavorite = false,
  }) {
    final Entry entry = Entry(
      malId: anime.malId,
      title: anime.title,
      coverUrl: anime.coverUrl,
      totalEpisodes: anime.totalEpisodes,
      status: status,
      updatedAt: DateTime.now(),
    ).withFavorite(isFavorite);
    return _repository.save(entry);
  }
}
