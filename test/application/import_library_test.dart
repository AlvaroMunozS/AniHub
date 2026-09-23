import 'package:anihub/application/usecases/usecases.dart';
import 'package:anihub/domain/entities/entry.dart';
import 'package:anihub/domain/values/watch_status.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/in_memory_entry_repository.dart';

Entry _entry({
  required int malId,
  required DateTime updatedAt,
  String? id,
  String title = 'Frieren',
  WatchStatus status = WatchStatus.planned,
  bool isFavorite = false,
}) {
  return Entry(
    id: id,
    malId: malId,
    title: title,
    status: status,
    updatedAt: updatedAt,
    isFavorite: isFavorite,
  );
}

void main() {
  late InMemoryEntryRepository repository;
  late ImportLibrary importLibrary;

  // Seeds through the constructor because `save` overwrites `updatedAt`.
  void seed(List<Entry> local) {
    repository = InMemoryEntryRepository(seed: local);
    addTearDown(repository.dispose);
    importLibrary = ImportLibrary(repository);
  }

  setUp(() => seed(const <Entry>[]));

  test('adds every entry to an empty library with a fresh id', () async {
    final ImportSummary summary = await importLibrary(<Entry>[
      _entry(malId: 1, updatedAt: DateTime.utc(2026)),
      _entry(malId: 2, updatedAt: DateTime.utc(2026)),
    ]);

    expect(summary.added, 2);
    expect(summary.updated, 0);
    expect(summary.unchanged, 0);
    final List<Entry> all = await repository.findAll();
    expect(all.map((Entry e) => e.malId), unorderedEquals(<int>[1, 2]));
    expect(all.every((Entry e) => e.id != null), isTrue);
  });

  test(
    'replaces a local entry with a newer one, keeping the local id',
    () async {
      seed(<Entry>[
        _entry(
          id: 'local-1',
          malId: 1,
          title: 'Old title',
          updatedAt: DateTime.utc(2020),
        ),
      ]);

      final ImportSummary summary = await importLibrary(<Entry>[
        _entry(
          malId: 1,
          title: 'New title',
          status: WatchStatus.completed,
          updatedAt: DateTime.utc(2025),
        ),
      ]);

      expect(summary.added, 0);
      expect(summary.updated, 1);
      expect(summary.unchanged, 0);
      final Entry result = (await repository.findAll()).single;
      expect(result.id, 'local-1');
      expect(result.title, 'New title');
      expect(result.status, WatchStatus.completed);
      expect(result.updatedAt, DateTime.utc(2025));
    },
  );

  test('ignores an incoming entry older than the local one', () async {
    seed(<Entry>[
      _entry(
        id: 'local-1',
        malId: 1,
        title: 'Local title',
        updatedAt: DateTime.utc(2025),
      ),
    ]);

    final ImportSummary summary = await importLibrary(<Entry>[
      _entry(malId: 1, title: 'Backup title', updatedAt: DateTime.utc(2020)),
    ]);

    expect(summary.added, 0);
    expect(summary.updated, 0);
    expect(summary.unchanged, 1);
    final Entry result = (await repository.findAll()).single;
    expect(result.id, 'local-1');
    expect(result.title, 'Local title');
  });

  test('ignores an incoming entry updated at the same instant', () async {
    final DateTime sameInstant = DateTime.utc(2025, 6, 1, 12);
    seed(<Entry>[
      _entry(
        id: 'local-1',
        malId: 1,
        title: 'Local title',
        updatedAt: sameInstant,
      ),
    ]);

    final ImportSummary summary = await importLibrary(<Entry>[
      _entry(malId: 1, title: 'Backup title', updatedAt: sameInstant),
    ]);

    expect(summary.unchanged, 1);
    expect((await repository.findAll()).single.title, 'Local title');
  });

  test('never deletes local entries missing from the backup', () async {
    seed(<Entry>[
      _entry(id: 'local-99', malId: 99, updatedAt: DateTime.utc(2026)),
    ]);

    await importLibrary(<Entry>[
      _entry(malId: 1, updatedAt: DateTime.utc(2026)),
    ]);

    expect(
      (await repository.findAll()).map((Entry e) => e.malId),
      unorderedEquals(<int>[1, 99]),
    );
  });

  test('changes nothing for an empty backup', () async {
    seed(<Entry>[
      _entry(id: 'local-1', malId: 1, updatedAt: DateTime.utc(2026)),
    ]);

    final ImportSummary summary = await importLibrary(const <Entry>[]);

    expect(summary.added, 0);
    expect(summary.updated, 0);
    expect(summary.unchanged, 0);
    expect(await repository.findAll(), hasLength(1));
  });

  test('counts added, updated and unchanged entries in one import', () async {
    seed(<Entry>[
      _entry(id: 'local-1', malId: 1, updatedAt: DateTime.utc(2020)),
      _entry(id: 'local-2', malId: 2, updatedAt: DateTime.utc(2025)),
    ]);

    final ImportSummary summary = await importLibrary(<Entry>[
      _entry(malId: 1, updatedAt: DateTime.utc(2025)),
      _entry(malId: 2, updatedAt: DateTime.utc(2020)),
      _entry(malId: 3, updatedAt: DateTime.utc(2024)),
    ]);

    expect(summary.added, 1);
    expect(summary.updated, 1);
    expect(summary.unchanged, 1);
    expect(await repository.findAll(), hasLength(3));
  });

  test('keeps the favorite of an incoming completed entry', () async {
    await importLibrary(<Entry>[
      _entry(
        malId: 1,
        status: WatchStatus.completed,
        isFavorite: true,
        updatedAt: DateTime.utc(2026),
      ),
    ]);

    final Entry result = (await repository.findAll()).single;
    expect(result.status, WatchStatus.completed);
    expect(result.isFavorite, isTrue);
  });
}
