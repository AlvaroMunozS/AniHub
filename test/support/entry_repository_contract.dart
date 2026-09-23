import 'package:anihub/domain/entities/entry.dart';
import 'package:anihub/domain/ports/entry_repository.dart';
import 'package:anihub/domain/values/watch_status.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a repository for one test, registering its own cleanup with
/// [addTearDown]. [now] is the clock that `save` must use.
typedef EntryRepositoryFactory = Future<EntryRepository> Function(
  DateTime Function() now,
);

/// Runs the behavior every [EntryRepository] shares against the repositories
/// built by [create].
///
/// [constraintError] matches the error that the implementation throws when a
/// write would store two entries with the same `id` or the same `malId`.
void entryRepositoryContract(
  EntryRepositoryFactory create, {
  required Matcher constraintError,
}) {
  late EntryRepository repo;
  late DateTime clock;

  // Every call advances the clock, so consecutive saves never tie.
  DateTime tick() => clock = clock.add(const Duration(minutes: 1));

  setUp(() async {
    clock = DateTime.utc(2024);
    repo = await create(tick);
  });

  Future<List<int>> storedMalIds() async =>
      (await repo.findAll()).map((Entry e) => e.malId).toList();

  test('starts empty', () async {
    expect(await repo.findAll(), isEmpty);
  });

  test('save inserts a new entry with an id and the current time', () async {
    final Entry entry = _entry(
      malId: 1,
      coverUrl: 'https://example.test/1.jpg',
      totalEpisodes: 28,
      status: WatchStatus.completed,
      isFavorite: true,
    );

    final Entry saved = await repo.save(entry);

    expect(saved.id, isNotEmpty);
    expect(saved, entry.copyWith(id: saved.id, updatedAt: clock));
    expect(await repo.findAll(), <Entry>[saved]);
  });

  test('save stores the timestamp in UTC', () async {
    final DateTime local = DateTime(2024, 3, 1, 12);
    final EntryRepository localRepo = await create(() => local);

    final Entry saved = await localRepo.save(_entry(malId: 1));

    expect(saved.updatedAt, local.toUtc());
    expect((await localRepo.findAll()).single.updatedAt, local.toUtc());
  });

  test('save updates an existing entry instead of duplicating it', () async {
    final Entry first = await repo.save(_entry(malId: 1));

    final Entry updated = await repo.save(
      first.withStatus(WatchStatus.completed),
    );

    expect(updated.id, first.id);
    expect(updated.updatedAt, clock);
    expect(await repo.findAll(), <Entry>[updated]);
  });

  test('save throws a StateError for an id that is not stored', () async {
    await expectLater(
      repo.save(_entry(id: 'missing', malId: 1)),
      throwsStateError,
    );
    expect(await repo.findAll(), isEmpty);
  });

  test('save rejects a second entry with the same malId', () async {
    final Entry first = await repo.save(_entry(malId: 42, title: 'A'));

    await expectLater(
      repo.save(_entry(malId: 42, title: 'B')),
      throwsA(constraintError),
    );
    expect(await repo.findAll(), <Entry>[first]);
  });

  test('delete removes the entry and ignores unknown ids', () async {
    final Entry kept = await repo.save(_entry(malId: 1));
    final Entry removed = await repo.save(_entry(malId: 2));

    await repo.delete(removed.id!);
    await repo.delete(removed.id!);

    expect(await repo.findAll(), <Entry>[kept]);
  });

  test('findAll returns the most recently saved first', () async {
    await repo.save(_entry(malId: 1));
    await repo.save(_entry(malId: 2));
    await repo.save(_entry(malId: 3));

    expect(await storedMalIds(), <int>[3, 2, 1]);
  });

  test('findAll orders entries saved within the same millisecond', () async {
    final DateTime start = DateTime.utc(2024, 3, 1, 12);
    final List<DateTime> times = <DateTime>[
      start,
      start.add(const Duration(microseconds: 1)),
      start.add(const Duration(microseconds: 2)),
    ];
    int saves = 0;
    final EntryRepository sameMillisecond = await create(() => times[saves++]);

    await sameMillisecond.save(_entry(malId: 1));
    await sameMillisecond.save(_entry(malId: 2));
    await sameMillisecond.save(_entry(malId: 3));

    expect(
      (await sameMillisecond.findAll()).map((Entry e) => e.updatedAt),
      times.reversed,
    );
  });

  test('watchAll emits the library on subscribe', () async {
    final Entry saved = await repo.save(_entry(malId: 1));

    await expectLater(repo.watchAll(), emits(<Entry>[saved]));
  });

  test('watchAll emits after every write, including one made right after '
      'subscribing', () async {
    final Future<void> emissions = expectLater(
      repo.watchAll().map(
        (List<Entry> entries) => entries.map((Entry e) => e.malId).toList(),
      ),
      emitsInOrder(<Object>[
        <int>[],
        <int>[1],
        <int>[2, 1],
        <int>[2],
      ]),
    );

    final Entry first = await repo.save(_entry(malId: 1));
    await repo.save(_entry(malId: 2));
    await repo.delete(first.id!);

    await emissions;
  });

  test('upsertAll inserts new entries keeping their id and updatedAt in '
      'UTC', () async {
    final DateTime local = DateTime(2022, 5, 1, 9);

    await repo.upsertAll(<Entry>[
      _entry(id: 'imported-id', malId: 7, updatedAt: local),
    ]);

    expect(await repo.findAll(), <Entry>[
      _entry(id: 'imported-id', malId: 7, updatedAt: local.toUtc()),
    ]);
  });

  test('upsertAll matches by malId, keeping the local id and taking the '
      'incoming fields', () async {
    final Entry existing = await repo.save(_entry(malId: 9, title: 'Old'));
    final Entry incoming = _entry(
      id: 'other-id',
      malId: 9,
      title: 'New',
      status: WatchStatus.completed,
      updatedAt: DateTime.utc(2030),
    );

    await repo.upsertAll(<Entry>[incoming]);

    expect(await repo.findAll(), <Entry>[incoming.copyWith(id: existing.id)]);
  });

  test('upsertAll with an empty list changes nothing', () async {
    final Entry saved = await repo.save(_entry(malId: 1));

    await repo.upsertAll(<Entry>[]);

    expect(await repo.findAll(), <Entry>[saved]);
  });

  test('upsertAll stores several entries, newest first', () async {
    await repo.upsertAll(<Entry>[
      _entry(malId: 1, updatedAt: DateTime.utc(2021)),
      _entry(malId: 3, updatedAt: DateTime.utc(2023)),
      _entry(malId: 2, updatedAt: DateTime.utc(2022)),
    ]);

    expect(await storedMalIds(), <int>[3, 2, 1]);
  });

  test('upsertAll leaves the library untouched when one entry is '
      'rejected', () async {
    final Entry existing = await repo.save(_entry(malId: 1));

    await expectLater(
      repo.upsertAll(<Entry>[
        _entry(malId: 2),
        _entry(id: existing.id, malId: 3),
      ]),
      throwsA(constraintError),
    );

    expect(await repo.findAll(), <Entry>[existing]);
  });
}

Entry _entry({
  String? id,
  required int malId,
  String title = 'Frieren',
  String? coverUrl,
  int? totalEpisodes,
  WatchStatus status = WatchStatus.planned,
  bool isFavorite = false,
  DateTime? updatedAt,
}) {
  return Entry(
    id: id,
    malId: malId,
    title: title,
    coverUrl: coverUrl,
    totalEpisodes: totalEpisodes,
    status: status,
    isFavorite: isFavorite,
    updatedAt: updatedAt ?? DateTime.utc(2000),
  );
}
