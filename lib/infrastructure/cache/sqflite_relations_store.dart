import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../domain/entities/anime_relation_node.dart';
import 'relations_cache_codec.dart';
import 'relations_cache_database.dart';
import 'relations_store.dart';

/// Preferences key of the relation graph snapshot that installs of AniHub
/// 1.1.0 and earlier hold, in the format read by [decodeRelationsCache].
const String relationsSnapshotKey = 'anihub.relations.cache';

/// [RelationsStore] backed by the `relation_nodes` table of `cache.db`.
///
/// Times are stored as microseconds since the epoch and read back in UTC.
/// A row whose node cannot be decoded is skipped.
class SqfliteRelationsStore implements RelationsStore {
  SqfliteRelationsStore(this._db, this._prefs);

  final Database _db;
  final SharedPreferences _prefs;

  @override
  Future<Map<int, CachedRelationNode>> loadAll() async {
    await _migrateSnapshot();
    final List<Map<String, Object?>> rows = await _db.query(relationNodesTable);
    return <int, CachedRelationNode>{
      for (final Map<String, Object?> row in rows)
        if (row case {
          'mal_id': final int malId,
          'saved_at': final int savedAt,
          'node': final String json,
        })
          if (decodeRelationNode(json) case final AnimeRelationNode node)
            malId: CachedRelationNode(
              savedAt: DateTime.fromMicrosecondsSinceEpoch(
                savedAt,
                isUtc: true,
              ),
              node: node,
            ),
    };
  }

  // Moves a snapshot left in preferences into the table, so an update keeps
  // the cache instead of fetching the whole library again. The key is removed
  // only after the insert, so a failed insert is retried on the next load.
  // A table that already has rows was migrated before, and its data is newer.
  Future<void> _migrateSnapshot() async {
    final String? snapshot = _prefs.getString(relationsSnapshotKey);
    if (snapshot == null) return;
    final int stored =
        Sqflite.firstIntValue(
          await _db.rawQuery('SELECT COUNT(*) FROM $relationNodesTable'),
        ) ??
        0;
    if (stored == 0) {
      final Map<int, CachedRelationNode>? nodes = decodeRelationsCache(
        snapshot,
      );
      if (nodes != null) await saveAll(nodes);
    }
    await _prefs.remove(relationsSnapshotKey);
  }

  @override
  Future<void> saveAll(Map<int, CachedRelationNode> nodes) {
    return _db.transaction((Transaction txn) async {
      final Batch batch = txn.batch();
      for (final MapEntry<int, CachedRelationNode>(:int key, :value)
          in nodes.entries) {
        batch.insert(relationNodesTable, <String, Object?>{
          'mal_id': key,
          'saved_at': value.savedAt.microsecondsSinceEpoch,
          'node': encodeRelationNode(value.node),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<void> deleteSavedBefore(DateTime cutoff) async {
    await _db.delete(
      relationNodesTable,
      where: 'saved_at < ?',
      whereArgs: <Object?>[cutoff.microsecondsSinceEpoch],
    );
  }
}
