import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../domain/entities/entry.dart';
import '../../domain/errors/duplicate_entry_exception.dart';
import '../../domain/ports/entry_repository.dart';
import '../../domain/values/watch_status.dart';
import 'uuid.dart';

const String _databaseFileName = 'library.db';

const int _schemaVersion = 2;

const String _entries = 'entries';

/// Opens the app database, creating its schema on first launch and
/// migrating it after an update.
///
/// There is no `onDowngrade`: Android refuses to install an older version
/// over a newer one.
Future<Database> openAniHubDatabase() async {
  final String path = p.join(await getDatabasesPath(), _databaseFileName);
  return openDatabase(
    path,
    version: _schemaVersion,
    onCreate: (Database db, int _) => createAniHubSchema(db),
    onUpgrade: upgradeAniHubSchema,
  );
}

/// Creates the AniHub tables and indexes in an empty [db].
///
/// Public so that tests can build the same schema on an in-memory database.
Future<void> createAniHubSchema(Database db) async {
  await _createEntriesTable(db, _entries);
  await _createEntriesIndex(db);
}

/// Migrates [db] from schema version [from] to [to].
///
/// Public so that tests can migrate an in-memory database. sqflite runs it
/// inside a transaction, so a failed step leaves the old schema intact.
Future<void> upgradeAniHubSchema(Database db, int from, int to) async {
  if (from < 2) await _migrateToV2(db);
}

Future<void> _createEntriesTable(DatabaseExecutor db, String table) {
  return db.execute('''
CREATE TABLE $table (
  id TEXT PRIMARY KEY,
  mal_id INTEGER NOT NULL UNIQUE,
  title TEXT NOT NULL,
  cover_url TEXT,
  total_episodes INTEGER,
  status TEXT NOT NULL CHECK(status IN ('watching', 'planned', 'completed')),
  is_favorite INTEGER NOT NULL DEFAULT 0
    CHECK(is_favorite = 0 OR status = 'completed'),
  updated_at INTEGER NOT NULL
)
''');
}

Future<void> _createEntriesIndex(DatabaseExecutor db) {
  return db.execute(
    'CREATE INDEX idx_entries_updated_at ON $_entries (updated_at)',
  );
}

// Schema 1 stored `updated_at` as ISO-8601 text, whose fraction of a second
// has three or six digits and so does not sort as time within a second, and
// allowed favorites that are not completed. SQLite cannot change a column's
// type in place, so the table is rebuilt. Timestamps are converted in Dart
// because `julianday` would lose the microseconds.
Future<void> _migrateToV2(Database db) async {
  const String next = '${_entries}_v2';
  await _createEntriesTable(db, next);
  final List<Map<String, Object?>> rows = await db.query(_entries);
  final Batch batch = db.batch();
  for (final Map<String, Object?> row in rows) {
    final bool isFavorite =
        row['is_favorite'] != 0 && row['status'] == WatchStatus.completed.wire;
    batch.insert(next, <String, Object?>{
      ...row,
      'is_favorite': isFavorite ? 1 : 0,
      'updated_at': DateTime.parse(row['updated_at']! as String)
          .microsecondsSinceEpoch,
    });
  }
  await batch.commit(noResult: true);
  await db.execute('DROP TABLE $_entries');
  await db.execute('ALTER TABLE $next RENAME TO $_entries');
  await _createEntriesIndex(db);
}

/// [EntryRepository] backed by the sqflite `entries` table.
class SqfliteEntryRepository implements EntryRepository {
  SqfliteEntryRepository(this._db, {this.now = DateTime.now});

  final Database _db;

  /// Source of the timestamp that [save] stamps on entries.
  final DateTime Function() now;

  final StreamController<List<Entry>> _changes =
      StreamController<List<Entry>>.broadcast();

  Future<List<Entry>> _fetchAll() async {
    final List<Map<String, Object?>> rows = await _db.query(
      _entries,
      orderBy: 'updated_at DESC',
    );
    return rows.map(_fromRow).toList(growable: false);
  }

  Future<void> _notifyChange() async {
    if (_changes.hasListener) _changes.add(await _fetchAll());
  }

  @override
  Future<List<Entry>> findAll() => _fetchAll();

  /// Throws a [StateError] if [entry] has an id that is not stored, and a
  /// [DuplicateEntryException] if another entry has the same `malId`.
  ///
  /// Duplicates are caught by the `mal_id` unique constraint rather than
  /// looked up first, so two concurrent inserts cannot both pass the check.
  @override
  Future<Entry> save(Entry entry) async {
    final String? existingId = entry.id;
    final String id = existingId ?? newUuidV4();
    final Entry saved = entry.copyWith(id: id, updatedAt: now().toUtc());
    final Map<String, Object?> row = _toRow(id, saved);

    try {
      if (existingId == null) {
        await _db.insert(_entries, row);
      } else {
        final int updated = await _db.update(
          _entries,
          row,
          where: 'id = ?',
          whereArgs: <Object?>[id],
        );
        if (updated == 0) throw StateError('No entry with id $id');
      }
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError('$_entries.mal_id')) {
        throw DuplicateEntryException(entry.malId);
      }
      rethrow;
    }

    await _notifyChange();
    return saved;
  }

  @override
  Future<void> delete(String id) async {
    await _db.delete(_entries, where: 'id = ?', whereArgs: <Object?>[id]);
    await _notifyChange();
  }

  @override
  Stream<List<Entry>> watchAll() {
    return Stream<List<Entry>>.multi((MultiStreamController<List<Entry>> out) {
      // Listening before the first read means no write can fall between the
      // two. A change that arrives first already holds newer data than the
      // first read, which is then dropped.
      bool changed = false;
      final StreamSubscription<List<Entry>> changes = _changes.stream.listen(
        (List<Entry> entries) {
          changed = true;
          out.add(entries);
        },
        onError: out.addError,
        onDone: out.close,
      );
      out.onCancel = changes.cancel;
      _fetchAll().then((List<Entry> entries) {
        if (!changed && !out.isClosed) out.add(entries);
      }, onError: out.addError);
    });
  }

  @override
  Future<void> upsertAll(List<Entry> entries) async {
    if (entries.isEmpty) return;

    final List<Map<String, Object?>> rows = <Map<String, Object?>>[
      for (final Entry entry in entries) _toRow(entry.id ?? newUuidV4(), entry),
    ];
    final String sql = _upsertSql(rows.first.keys);
    await _db.transaction((Transaction txn) async {
      for (final Map<String, Object?> row in rows) {
        await txn.rawInsert(sql, row.values.toList());
      }
    });

    await _notifyChange();
  }

  /// Closes the change stream. The [Database] is owned by the caller and must
  /// be closed separately.
  Future<void> dispose() => _changes.close();
}

// Conflicts are resolved on `mal_id`, not on `id`, so an imported entry
// updates the local copy of the same anime and keeps its local id.
String _upsertSql(Iterable<String> columns) {
  final Iterable<String> updated = columns.where(
    (String column) => column != 'id' && column != 'mal_id',
  );
  return 'INSERT INTO $_entries (${columns.join(', ')}) '
      'VALUES (${List<String>.filled(columns.length, '?').join(', ')}) '
      'ON CONFLICT(mal_id) DO UPDATE SET '
      '${updated.map((String column) => '$column = excluded.$column').join(', ')}';
}

Entry _fromRow(Map<String, Object?> row) {
  return Entry(
    id: row['id']! as String,
    malId: row['mal_id']! as int,
    title: row['title']! as String,
    coverUrl: row['cover_url'] as String?,
    totalEpisodes: row['total_episodes'] as int?,
    status: WatchStatus.fromWire(row['status']! as String),
    isFavorite: (row['is_favorite']! as int) != 0,
    updatedAt: DateTime.fromMicrosecondsSinceEpoch(
      row['updated_at']! as int,
      isUtc: true,
    ),
  );
}

Map<String, Object?> _toRow(String id, Entry entry) {
  return <String, Object?>{
    'id': id,
    'mal_id': entry.malId,
    'title': entry.title,
    'cover_url': entry.coverUrl,
    'total_episodes': entry.totalEpisodes,
    'status': entry.status.wire,
    'is_favorite': entry.isFavorite ? 1 : 0,
    'updated_at': entry.updatedAt.microsecondsSinceEpoch,
  };
}
