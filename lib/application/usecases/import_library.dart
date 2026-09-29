import '../../domain/entities/entry.dart';
import '../../domain/ports/entry_repository.dart';

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
/// An incoming `updatedAt` more than [futureTolerance] ahead of the clock is
/// taken as now, and such an entry is only ever inserted: a date invented by
/// a wrong clock must not replace a local entry, and clamping to the moment of
/// each import would make it newer than every earlier edit.
///
/// Writes go through [EntryRepository.upsertAll] so that imported timestamps
/// are preserved.
class ImportLibrary {
  const ImportLibrary(this._repository, this._now);

  static const Duration futureTolerance = Duration(hours: 24);

  final EntryRepository _repository;
  final DateTime Function() _now;

  bool _isFuture(Entry entry, DateTime now) =>
      entry.updatedAt.isAfter(now.add(futureTolerance));

  Future<ImportSummary> call(List<Entry> entries) async {
    final List<Entry> existing = await _repository.findAll();
    final Map<int, Entry> byMalId = <int, Entry>{
      for (final Entry entry in existing) entry.malId: entry,
    };

    final DateTime now = _now();
    final List<Entry> toPersist = <Entry>[];
    int added = 0;
    int updated = 0;
    int unchanged = 0;

    for (final Entry incoming in entries) {
      final bool future = _isFuture(incoming, now);
      final Entry? current = byMalId[incoming.malId];
      if (current == null) {
        toPersist.add(future ? incoming.copyWith(updatedAt: now) : incoming);
        added++;
      } else if (!future && incoming.updatedAt.isAfter(current.updatedAt)) {
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
