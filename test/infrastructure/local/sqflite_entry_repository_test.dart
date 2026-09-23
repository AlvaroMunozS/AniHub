import 'dart:io';

import 'package:anihub/domain/entities/entry.dart';
import 'package:anihub/domain/values/watch_status.dart';
import 'package:anihub/infrastructure/local/sqflite_entry_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sqflite show databaseFactory;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../support/entry_repository_contract.dart';

Future<Database> _openInMemory({
  required int version,
  required OnDatabaseCreateFn onCreate,
}) async {
  final Database db = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: version,
      singleInstance: false,
      onCreate: onCreate,
    ),
  );
  addTearDown(db.close);
  return db;
}

Future<Database> _openCurrentSchema() => _openInMemory(
  version: 2,
  onCreate: (Database db, int _) => createAniHubSchema(db),
);

/// Builds schema version 1, with `updated_at` as ISO-8601 text.
Future<void> _createSchemaV1(Database db, int _) async {
  await db.execute('''
CREATE TABLE entries (
  id TEXT PRIMARY KEY,
  mal_id INTEGER NOT NULL UNIQUE,
  title TEXT NOT NULL,
  cover_url TEXT,
  total_episodes INTEGER,
  status TEXT NOT NULL CHECK(status IN ('watching', 'planned', 'completed')),
  is_favorite INTEGER NOT NULL DEFAULT 0,
  updated_at TEXT NOT NULL
)
''');
  await db.execute(
    'CREATE INDEX idx_entries_updated_at ON entries (updated_at)',
  );
}

Map<String, Object?> _rowV1({
  required String id,
  required int malId,
  required String status,
  required String updatedAt,
  int isFavorite = 0,
}) => <String, Object?>{
  'id': id,
  'mal_id': malId,
  'title': 'Title $malId',
  'cover_url': 'https://example.test/$malId.jpg',
  'total_episodes': 12,
  'status': status,
  'is_favorite': isFavorite,
  'updated_at': updatedAt,
};

void main() {
  sqfliteFfiInit();

  entryRepositoryContract((DateTime Function() now) async {
    final Database db = await _openCurrentSchema();
    final SqfliteEntryRepository repo = SqfliteEntryRepository(db, now: now);
    addTearDown(repo.dispose);
    return repo;
  }, constraintError: isA<DatabaseException>());

  test('the schema rejects a favorite that is not completed', () async {
    final Database db = await _openCurrentSchema();

    await expectLater(
      db.insert('entries', <String, Object?>{
        'id': 'a',
        'mal_id': 1,
        'title': 'Frieren',
        'status': 'watching',
        'is_favorite': 1,
        'updated_at': 0,
      }),
      throwsA(isA<DatabaseException>()),
    );
  });

  group('upgrade from version 1', () {
    late Database db;

    setUp(() async {
      db = await _openInMemory(version: 1, onCreate: _createSchemaV1);
    });

    Future<List<Entry>> readAll() async {
      final SqfliteEntryRepository repo = SqfliteEntryRepository(db);
      addTearDown(repo.dispose);
      return repo.findAll();
    }

    test('keeps every field and stores updatedAt in microseconds', () async {
      await db.insert(
        'entries',
        _rowV1(
          id: 'a',
          malId: 1,
          status: 'completed',
          isFavorite: 1,
          updatedAt: '2024-03-01T12:00:00.123456Z',
        ),
      );

      await upgradeAniHubSchema(db, 1, 2);

      final DateTime updatedAt = DateTime.utc(2024, 3, 1, 12, 0, 0, 123, 456);
      final Map<String, Object?> row = (await db.query('entries')).single;
      expect(row['updated_at'], updatedAt.microsecondsSinceEpoch);
      expect(await readAll(), <Entry>[
        Entry(
          id: 'a',
          malId: 1,
          title: 'Title 1',
          coverUrl: 'https://example.test/1.jpg',
          totalEpisodes: 12,
          status: WatchStatus.completed,
          isFavorite: true,
          updatedAt: updatedAt,
        ),
      ]);
    });

    test('orders entries that differ by less than a millisecond', () async {
      await db.insert(
        'entries',
        _rowV1(
          id: 'a',
          malId: 1,
          status: 'planned',
          updatedAt: '2024-03-01T12:00:00.000Z',
        ),
      );
      await db.insert(
        'entries',
        _rowV1(
          id: 'b',
          malId: 2,
          status: 'planned',
          updatedAt: '2024-03-01T12:00:00.000001Z',
        ),
      );

      await upgradeAniHubSchema(db, 1, 2);

      expect((await readAll()).map((Entry e) => e.malId), <int>[2, 1]);
    });

    test('keeps the status and drops the favorite of an entry that is not '
        'completed', () async {
      await db.insert(
        'entries',
        _rowV1(
          id: 'a',
          malId: 1,
          status: 'watching',
          isFavorite: 1,
          updatedAt: '2024-03-01T12:00:00.000Z',
        ),
      );

      await upgradeAniHubSchema(db, 1, 2);

      final Entry entry = (await readAll()).single;
      expect(entry.status, WatchStatus.watching);
      expect(entry.isFavorite, isFalse);
    });

    test('recreates the updatedAt index', () async {
      await upgradeAniHubSchema(db, 1, 2);

      final List<Map<String, Object?>> indexes = await db.query(
        'sqlite_master',
        where: 'type = ? AND tbl_name = ?',
        whereArgs: <Object?>['index', 'entries'],
      );
      expect(
        indexes.map((Map<String, Object?> row) => row['name']),
        contains('idx_entries_updated_at'),
      );
    });
  });

  test('openAniHubDatabase upgrades a version 1 library on disk', () async {
    final Directory dir = await Directory.systemTemp.createTemp('anihub_db');
    addTearDown(() => dir.delete(recursive: true));
    sqflite.databaseFactory = databaseFactoryFfi;
    await databaseFactoryFfi.setDatabasesPath(dir.path);
    final Database v1 = await databaseFactoryFfi.openDatabase(
      p.join(dir.path, 'library.db'),
      options: OpenDatabaseOptions(version: 1, onCreate: _createSchemaV1),
    );
    await v1.insert(
      'entries',
      _rowV1(
        id: 'a',
        malId: 1,
        status: 'completed',
        isFavorite: 1,
        updatedAt: '2024-03-01T12:00:00.000Z',
      ),
    );
    await v1.insert(
      'entries',
      _rowV1(
        id: 'b',
        malId: 2,
        status: 'watching',
        isFavorite: 1,
        updatedAt: '2024-03-01T12:00:00.000001Z',
      ),
    );
    await v1.close();

    final Database db = await openAniHubDatabase();
    addTearDown(db.close);

    expect(await db.getVersion(), 2);
    final SqfliteEntryRepository repo = SqfliteEntryRepository(db);
    addTearDown(repo.dispose);
    expect(
      (await repo.findAll()).map(
        (Entry e) => (e.malId, e.status, e.isFavorite),
      ),
      <(int, WatchStatus, bool)>[
        (2, WatchStatus.watching, false),
        (1, WatchStatus.completed, true),
      ],
    );
    await expectLater(
      db.update('entries', <String, Object?>{
        'is_favorite': 1,
      }, where: "id = 'b'"),
      throwsA(isA<DatabaseException>()),
    );
    final List<Map<String, Object?>> indexes = await db.query(
      'sqlite_master',
      where: 'type = ? AND name = ?',
      whereArgs: <Object?>['index', 'idx_entries_updated_at'],
    );
    expect(indexes, hasLength(1));
  });
}
