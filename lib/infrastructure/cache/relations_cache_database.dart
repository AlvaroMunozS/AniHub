import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

const String _databaseFileName = 'cache.db';

// The `node` column holds the JSON of `encodeRelationNode`. An incompatible
// change to it needs a new version whose upgrade empties the table, since
// everything in it can be fetched again.
const int _schemaVersion = 2;

/// Table of cached relation nodes, one row per anime.
const String relationNodesTable = 'relation_nodes';

/// Where the relation cache database lives.
///
/// Kept apart from the library database so that the cache never takes part
/// in the library's migrations and can be dropped without touching it.
Future<String> relationsCachePath() async =>
    p.join(await getDatabasesPath(), _databaseFileName);

/// Opens the relation cache database at [path] with [factory], creating its
/// schema on first launch.
///
/// Everything in the cache can be fetched again, so a corrupt file is deleted
/// and recreated once. Any other error, such as a full disk or a permission
/// problem, is rethrown without touching the file, since deleting it would
/// not help. Public so that tests can pass their own factory and path.
Future<Database> openRelationsCacheDatabaseAt(
  DatabaseFactory factory,
  String path,
) async {
  final OpenDatabaseOptions options = OpenDatabaseOptions(
    version: _schemaVersion,
    onCreate: (Database db, int _) => createRelationsCacheSchema(db),
    // Cached nodes may hold relations to hentai, which are no longer kept.
    onUpgrade: (Database db, int _, int _) => db.delete(relationNodesTable),
  );
  try {
    return await factory.openDatabase(path, options: options);
  } on DatabaseException catch (error) {
    if (!_isCorruption(error)) rethrow;
    debugPrint('Relations cache recreated: $error');
    await factory.deleteDatabase(path);
    return factory.openDatabase(path, options: options);
  }
}

// SQLITE_CORRUPT and SQLITE_NOTADB. Android and ffi report extended result
// codes, whose low byte is the primary one.
bool _isCorruption(DatabaseException error) {
  final int? code = error.getResultCode();
  if (code == null) return false;
  final int primary = code & 0xFF;
  return primary == 11 || primary == 26;
}

/// Creates the relation cache tables and indexes in an empty [db].
///
/// Public so that tests can build the same schema on an in-memory database.
Future<void> createRelationsCacheSchema(Database db) async {
  await db.execute('''
CREATE TABLE $relationNodesTable (
  mal_id INTEGER PRIMARY KEY,
  saved_at INTEGER NOT NULL,
  node TEXT NOT NULL
)
''');
  await db.execute(
    'CREATE INDEX idx_relation_nodes_saved_at '
    'ON $relationNodesTable (saved_at)',
  );
}
