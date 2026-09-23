import '../../domain/entities/entry.dart';
import '../../domain/ports/entry_repository.dart';
import '../../domain/values/watch_status.dart';

/// Number of entries added, updated, and left unchanged by an import.
class ImportSummary {
  const ImportSummary({
    required this.added,
    required this.updated,
    required this.unchanged,
  });

  final int added;
  final int updated;
  final int unchanged;

  @override
  String toString() =>
      'ImportSummary(added: $added, updated: $updated, unchanged: $unchanged)';
}

/// Merges backup entries into the library, matching them by `malId`.
///
/// An incoming entry is inserted if it is missing locally, replaces the local
/// one (keeping the local `id`) if its `updatedAt` is strictly newer, and is
/// ignored otherwise. Local entries are never deleted.
///
/// An incoming favorite that is not [WatchStatus.completed] keeps its status
/// and loses the favorite flag, because only completed entries can be
/// favorites.
///
/// Writes go through [EntryRepository.upsertAll] so that imported timestamps
/// are preserved.
class ImportLibrary {
  const ImportLibrary(this._repository);

  final EntryRepository _repository;

  Future<ImportSummary> call(List<Entry> entries) async {
    final List<Entry> existing = await _repository.findAll();
    final Map<int, Entry> byMalId = <int, Entry>{
      for (final Entry entry in existing) entry.malId: entry,
    };

    final List<Entry> toPersist = <Entry>[];
    int added = 0;
    int updated = 0;
    int unchanged = 0;

    for (final Entry candidate in entries) {
      final Entry incoming =
          candidate.isFavorite && candidate.status != WatchStatus.completed
          ? candidate.copyWith(isFavorite: false)
          : candidate;
      final Entry? current = byMalId[incoming.malId];
      if (current == null) {
        toPersist.add(incoming);
        added++;
      } else if (incoming.updatedAt.isAfter(current.updatedAt)) {
        toPersist.add(incoming.copyWith(id: current.id));
        updated++;
      } else {
        unchanged++;
      }
    }

    if (toPersist.isNotEmpty) {
      await _repository.upsertAll(toPersist);
    }

    return ImportSummary(added: added, updated: updated, unchanged: unchanged);
  }
}
