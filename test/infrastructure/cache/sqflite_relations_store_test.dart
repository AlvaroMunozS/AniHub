import 'package:anihub/domain/entities/anime_relation.dart';
import 'package:anihub/domain/entities/anime_relation_node.dart';
import 'package:anihub/domain/values/relation_kind.dart';
import 'package:anihub/infrastructure/cache/relations_cache_codec.dart';
import 'package:anihub/infrastructure/cache/relations_cache_database.dart';
import 'package:anihub/infrastructure/cache/sqflite_relations_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const String _snapshot =
    '{"v":1,"nodes":{"21":{"savedAt":"2024-01-01T00:00:00.000Z",'
    '"node":{"malId":21,"title":"One Piece","relations":[{"malId":5114,'
    '"kind":"sequel","title":"FMA"}]}}}}';

CachedRelationNode _cached(int id, DateTime savedAt, {String title = 'A'}) =>
    CachedRelationNode(
      savedAt: savedAt,
      node: AnimeRelationNode(malId: id, title: title),
    );

void main() {
  sqfliteFfiInit();

  late Database db;

  Future<SqfliteRelationsStore> openStore([
    Map<String, Object> prefs = const <String, Object>{},
  ]) async {
    SharedPreferences.setMockInitialValues(prefs);
    return SqfliteRelationsStore(db, await SharedPreferences.getInstance());
  }

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        singleInstance: false,
        onCreate: (Database db, int _) => createRelationsCacheSchema(db),
      ),
    );
    addTearDown(db.close);
  });

  test('loads nothing from an empty database', () async {
    final SqfliteRelationsStore store = await openStore();

    expect(await store.loadAll(), isEmpty);
  });

  test('saves nodes and loads them back in UTC to the microsecond', () async {
    final SqfliteRelationsStore store = await openStore();
    final Map<int, CachedRelationNode> nodes = <int, CachedRelationNode>{
      1: _cached(1, DateTime.utc(2024, 1, 2, 3, 4, 5, 6, 7)),
      2: _cached(2, DateTime.utc(2024)),
    };

    await store.saveAll(nodes);

    expect(await store.loadAll(), nodes);
  });

  test('replaces a stored node with the same id', () async {
    final SqfliteRelationsStore store = await openStore();
    await store.saveAll(<int, CachedRelationNode>{
      1: _cached(1, DateTime.utc(2024)),
      2: _cached(2, DateTime.utc(2024)),
    });

    await store.saveAll(<int, CachedRelationNode>{
      1: _cached(1, DateTime.utc(2025), title: 'B'),
    });

    expect(await store.loadAll(), <int, CachedRelationNode>{
      1: _cached(1, DateTime.utc(2025), title: 'B'),
      2: _cached(2, DateTime.utc(2024)),
    });
  });

  test('deletes only the nodes saved before the cutoff', () async {
    final SqfliteRelationsStore store = await openStore();
    await store.saveAll(<int, CachedRelationNode>{
      1: _cached(1, DateTime.utc(2023)),
      2: _cached(2, DateTime.utc(2024)),
      3: _cached(3, DateTime.utc(2025)),
    });

    await store.deleteSavedBefore(DateTime.utc(2024));

    expect((await store.loadAll()).keys, unorderedEquals(<int>[2, 3]));
  });

  test('skips a row whose node cannot be decoded', () async {
    final SqfliteRelationsStore store = await openStore();
    await store.saveAll(<int, CachedRelationNode>{
      1: _cached(1, DateTime.utc(2024)),
    });
    await db.insert(relationNodesTable, <String, Object?>{
      'mal_id': 2,
      'saved_at': 0,
      'node': '{not json',
    });

    expect((await store.loadAll()).keys, <int>[1]);
  });

  test('moves the preferences snapshot into the table and removes the '
      'key', () async {
    final SqfliteRelationsStore store = await openStore(<String, Object>{
      relationsSnapshotKey: _snapshot,
    });
    final CachedRelationNode expected = CachedRelationNode(
      savedAt: DateTime.utc(2024),
      node: const AnimeRelationNode(
        malId: 21,
        title: 'One Piece',
        relations: <AnimeRelation>[
          AnimeRelation(malId: 5114, kind: RelationKind.sequel, title: 'FMA'),
        ],
      ),
    );

    expect(await store.loadAll(), <int, CachedRelationNode>{21: expected});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(relationsSnapshotKey), isFalse);
    expect(
      await SqfliteRelationsStore(db, prefs).loadAll(),
      <int, CachedRelationNode>{21: expected},
    );
  });

  test('keeps the rows of a table that already has data and removes the '
      'snapshot', () async {
    final SqfliteRelationsStore store = await openStore(<String, Object>{
      relationsSnapshotKey: _snapshot,
    });
    await store.saveAll(<int, CachedRelationNode>{
      1: _cached(1, DateTime.utc(2025)),
    });

    expect((await store.loadAll()).keys, <int>[1]);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(relationsSnapshotKey), isFalse);
  });

  test('removes a snapshot that cannot be read', () async {
    final SqfliteRelationsStore store = await openStore(<String, Object>{
      relationsSnapshotKey: '{not json',
    });

    expect(await store.loadAll(), isEmpty);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(relationsSnapshotKey), isFalse);
  });

  test('keeps the snapshot when moving it fails and moves it on the next '
      'load', () async {
    final SqfliteRelationsStore store = await openStore(<String, Object>{
      relationsSnapshotKey: _snapshot,
    });
    await db.execute(
      'CREATE TRIGGER refuse_inserts BEFORE INSERT ON $relationNodesTable '
      "BEGIN SELECT RAISE(ABORT, 'disk full'); END",
    );

    await expectLater(store.loadAll(), throwsA(isA<DatabaseException>()));
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(relationsSnapshotKey), isTrue);

    await db.execute('DROP TRIGGER refuse_inserts');

    expect((await store.loadAll()).keys, <int>[21]);
    expect(prefs.containsKey(relationsSnapshotKey), isFalse);
  });
}
