import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

const String _databaseFileName = 'cache.db';

// The `node` column holds the JSON of `encodeRelationNode`. An incompatible
// change to it needs a new version whose upgrade empties the table, since
// everything in it can be fetched again.
const int _schemaVersion = 1;

/// Table of cached relation nodes, one row per anime.
const String relationNodesTable = 'relation_nodes';

/// Opens the relation cache database, creating its schema on first launch.
///
/// Kept apart from the library database so that the cache never takes part
/// in the library's migrations and can be dropped without touching it.
Future<Database> openRelationsCacheDatabase() async {
  return openRelationsCacheDatabaseAt(
    databaseFactory,
    p.join(await getDatabasesPath(), _databaseFileName),
  );
}

/// Opens the relation cache database at [path] with [factory], deleting and
/// recreating it once if it cannot be opened.
///
/// Everything in the cache can be fetched again, so a corrupt file must not
/// keep the app from starting. Public so that tests can pass their own
/// factory and path.
Future<Database> openRelationsCacheDatabaseAt(
  DatabaseFactory factory,
  String path,
) async {
  final OpenDatabaseOptions options = OpenDatabaseOptions(
    version: _schemaVersion,
    onCreate: (Database db, int _) => createRelationsCacheSchema(db),
  );
  try {
    return await factory.openDatabase(path, options: options);
  } on Object catch (error) {
    debugPrint('Relations cache recreated: $error');
    await factory.deleteDatabase(path);
    return factory.openDatabase(path, options: options);
  }
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
