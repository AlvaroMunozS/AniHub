import '../../domain/entities/catalog_anime.dart';
import '../../domain/entities/entry.dart';
import '../../domain/ports/entry_repository.dart';
import '../../domain/values/watch_status.dart';
import 'duplicate_entry_exception.dart';

/// Adds a catalog anime to the library.
///
/// A favorite is always stored as [WatchStatus.completed], whatever [status]
/// is passed, because only completed entries can be favorites.
///
/// Throws a [DuplicateEntryException] without writing anything if an entry
/// with the same `malId` already exists. The check is done here rather
/// than left to a storage constraint so that every [EntryRepository] reports
/// duplicates the same way.
class AddEntry {
  const AddEntry(this._repository);

  final EntryRepository _repository;

  Future<Entry> call(
    CatalogAnime anime, {
    WatchStatus status = WatchStatus.planned,
    bool isFavorite = false,
  }) async {
    final List<Entry> existing = await _repository.findAll();
    final bool alreadyInLibrary = existing.any(
      (Entry entry) => entry.malId == anime.malId,
    );
    if (alreadyInLibrary) {
      throw DuplicateEntryException(anime.malId);
    }

    final Entry entry = Entry(
      malId: anime.malId,
      title: anime.title,
      coverUrl: anime.coverUrl,
      totalEpisodes: anime.totalEpisodes,
      status: isFavorite ? WatchStatus.completed : status,
      isFavorite: isFavorite,
      updatedAt: DateTime.now(),
    );
    return _repository.save(entry);
  }
}
