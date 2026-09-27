import 'package:anihub/application/usecases/usecases.dart';
import 'package:anihub/domain/entities/entry.dart';
import 'package:anihub/domain/values/watch_status.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_library_backups.dart';
import '../support/in_memory_entry_repository.dart';

final DateTime _exportedAt = DateTime.utc(2026, 9, 27, 18);

Entry _entry(int malId, WatchStatus status) {
  return Entry(
    malId: malId,
    title: 'Anime $malId',
    status: status,
    updatedAt: DateTime.utc(2026, 9, malId),
  );
}

void main() {
  InMemoryEntryRepository library(List<Entry> entries) {
    final InMemoryEntryRepository repository = InMemoryEntryRepository(
      seed: entries,
    );
    addTearDown(repository.dispose);
    return repository;
  }

  test('saves every entry in every status and returns the count', () async {
    final InMemoryEntryRepository repository = library(<Entry>[
      _entry(1, WatchStatus.watching),
      _entry(2, WatchStatus.planned),
      _entry(3, WatchStatus.completed),
    ]);
    final FakeLibraryBackups backups = FakeLibraryBackups(saveResult: true);

    final int? exported = await ExportLibrary(repository, backups)(_exportedAt);

    expect(exported, 3);
    expect(backups.savedEntries, await repository.findAll());
    expect(backups.savedAt, _exportedAt);
  });

  test('returns 0 without asking where to save an empty library', () async {
    final FakeLibraryBackups backups = FakeLibraryBackups(saveResult: true);

    final int? exported = await ExportLibrary(
      library(const <Entry>[]),
      backups,
    )(_exportedAt);

    expect(exported, 0);
    expect(backups.savedEntries, isNull);
  });

  test('returns null when the user cancels the save', () async {
    final FakeLibraryBackups backups = FakeLibraryBackups();

    final int? exported = await ExportLibrary(
      library(<Entry>[_entry(1, WatchStatus.planned)]),
      backups,
    )(_exportedAt);

    expect(exported, isNull);
    expect(backups.savedEntries, hasLength(1));
  });
}
