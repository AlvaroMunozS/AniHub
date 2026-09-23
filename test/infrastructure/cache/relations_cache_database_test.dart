import 'dart:io';

import 'package:anihub/infrastructure/cache/relations_cache_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late String path;

  setUp(() async {
    final Directory dir = await Directory.systemTemp.createTemp('anihub_');
    addTearDown(() => dir.delete(recursive: true));
    path = p.join(dir.path, 'cache.db');
  });

  Future<Database> open() async {
    final Database db = await openRelationsCacheDatabaseAt(
      databaseFactoryFfi,
      path,
    );
    addTearDown(db.close);
    return db;
  }

  Future<List<String?>> namesOf(Database db, String type) async {
    final List<Map<String, Object?>> rows = await db.query(
      'sqlite_master',
      columns: <String>['name'],
      where: 'type = ?',
      whereArgs: <Object?>[type],
    );
    return <String?>[
      for (final Map<String, Object?> row in rows) row['name'] as String?,
    ];
  }

  test('creates the node table and its saved_at index', () async {
    final Database db = await open();

    expect(await namesOf(db, 'table'), contains(relationNodesTable));
    expect(await namesOf(db, 'index'), contains('idx_relation_nodes_saved_at'));
  });

  test('recreates a file that is not a database', () async {
    final List<String?> logs = <String?>[];
    final DebugPrintCallback originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) => logs.add(message);
    addTearDown(() => debugPrint = originalDebugPrint);
    await File(path).writeAsString('not a database, just some text ' * 100);

    final Database db = await open();

    expect(await db.query(relationNodesTable), isEmpty);
    expect(logs, <Object>[contains('Relations cache recreated')]);
  });
}
