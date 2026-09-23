import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../domain/entities/entry.dart';
import '../../domain/ports/entry_repository.dart';
import '../../domain/values/watch_status.dart';
import 'uuid.dart';

const String _databaseFileName = 'library.db';

const int _schemaVersion = 1;

const String _entries = 'entries';

/// Opens the app database, creating its schema on first launch.
Future<Database> openAniHubDatabase() async {
  final String path = p.join(await getDatabasesPath(), _databaseFileName);
  return openDatabase(
    path,
    version: _schemaVersion,
    onCreate: (Database db, int _) => createAniHubSchema(db),
  );
}

/// Creates the AniHub tables and indexes in an empty [db].
///
/// Public so that tests can build the same schema on an in-memory database.
Future<void> createAniHubSchema(Database db) async {
  await db.execute('''
CREATE TABLE $_entries (
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
    'CREATE INDEX idx_entries_updated_at ON $_entries (updated_at)',
  );
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
  /// [DatabaseException] if another entry has the same `malId`.
  @override
  Future<Entry> save(Entry entry) async {
    final String? existingId = entry.id;
    final String id = existingId ?? newUuidV4();
    final Entry saved = entry.copyWith(id: id, updatedAt: now().toUtc());
    final Map<String, Object?> row = _toRow(id, saved);

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
    updatedAt: DateTime.parse(row['updated_at']! as String),
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
    'updated_at': entry.updatedAt.toUtc().toIso8601String(),
  };
}
