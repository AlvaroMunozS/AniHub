import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'relations_cache_codec.dart';
import 'relations_cache_database.dart';
import 'relations_store.dart';
import 'sqflite_relations_store.dart';

/// Opens the relations store on `cache.db`, or one held in memory when the
/// file cannot be opened.
///
/// The cache is optional: without it relations are fetched again on every
/// launch, which is better than an app that does not start. That includes not
/// finding where the file lives, so [locate] runs inside the guard. [factory]
/// and [locate] default to the device's; tests pass their own.
Future<RelationsStore> openRelationsStore(
  SharedPreferences prefs, {
  DatabaseFactory? factory,
  Future<String> Function() locate = relationsCachePath,
}) async {
  try {
    return SqfliteRelationsStore(
      await openRelationsCacheDatabaseAt(
        factory ?? databaseFactory,
        await locate(),
      ),
      prefs,
    );
  } on Object catch (error) {
    debugPrint('Relations cache unavailable, using memory: $error');
    return _MemoryRelationsStore();
  }
}

class _MemoryRelationsStore implements RelationsStore {
  final Map<int, CachedRelationNode> _nodes = <int, CachedRelationNode>{};

  @override
  Future<Map<int, CachedRelationNode>> loadAll() async =>
      Map<int, CachedRelationNode>.of(_nodes);

  @override
  Future<void> saveAll(Map<int, CachedRelationNode> nodes) async =>
      _nodes.addAll(nodes);

  @override
  Future<void> deleteSavedBefore(DateTime cutoff) async => _nodes.removeWhere(
    (int _, CachedRelationNode node) => node.savedAt.isBefore(cutoff),
  );
}
