import 'package:anihub/infrastructure/cache/relations_store.dart';
import 'package:anihub/infrastructure/cache/relations_store_opener.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

class _MockDatabaseFactory extends Mock implements DatabaseFactory {}

// `SqfliteDatabaseException` is not exported by sqflite, so this stands in
// for it with the result code that sqflite would parse from the message.
class _CodedDatabaseException extends DatabaseException {
  _CodedDatabaseException(this._code) : super('open failed (code $_code)');

  final int _code;

  @override
  Object? get result => null;

  @override
  int? getResultCode() => _code;
}

void main() {
  late _MockDatabaseFactory factory;

  setUp(() {
    factory = _MockDatabaseFactory();
    when(() => factory.deleteDatabase(any())).thenAnswer((_) async {});
    final DebugPrintCallback originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {};
    addTearDown(() => debugPrint = originalDebugPrint);
  });

  void openFailsWith(Object error) {
    when(() => factory.openDatabase(any(), options: any(named: 'options')))
        .thenThrow(error);
  }

  Future<RelationsStore> open({
    Future<String> Function() locate = _cachePath,
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    return openRelationsStore(
      await SharedPreferences.getInstance(),
      factory: factory,
      locate: locate,
    );
  }

  test('starts with an empty store when cache.db cannot be opened', () async {
    openFailsWith(StateError('cannot open'));

    final RelationsStore store = await open();

    expect(await store.loadAll(), isEmpty);
    await store.deleteSavedBefore(DateTime.utc(2026));
  });

  test(
    'starts with an empty store when the databases path is unknown',
    () async {
      final RelationsStore store = await open(
        locate: () async => throw StateError('no databases path'),
      );

      expect(await store.loadAll(), isEmpty);
      verifyNever(
        () => factory.openDatabase(any(), options: any(named: 'options')),
      );
    },
  );

  test('does not delete cache.db when the error is not corruption', () async {
    openFailsWith(StateError('cannot open'));

    await open();

    verifyNever(() => factory.deleteDatabase(any()));
  });

  test(
    'starts with an empty store when a recreated cache.db fails too',
    () async {
      openFailsWith(_CodedDatabaseException(26));

      final RelationsStore store = await open();

      expect(await store.loadAll(), isEmpty);
      verify(() => factory.deleteDatabase('cache.db')).called(1);
      verify(() => factory.openDatabase(any(), options: any(named: 'options')))
          .called(2);
    },
  );

  for (final (String, int) code in <(String, int)>[
    ('SQLITE_CORRUPT', 11),
    ('SQLITE_NOTADB', 26),
    ('an extended SQLITE_CORRUPT_VTAB', 267),
    ('an extended SQLITE_NOTADB', 282),
  ]) {
    test('deletes cache.db on ${code.$1}', () async {
      openFailsWith(_CodedDatabaseException(code.$2));

      await open();

      verify(() => factory.deleteDatabase('cache.db')).called(1);
    });
  }

  for (final (String, int) code in <(String, int)>[
    ('SQLITE_FULL', 13),
    ('an extended SQLITE_READONLY_DBMOVED', 1032),
  ]) {
    test('keeps cache.db on ${code.$1}', () async {
      openFailsWith(_CodedDatabaseException(code.$2));

      await open();

      verifyNever(() => factory.deleteDatabase(any()));
    });
  }
}

Future<String> _cachePath() async => 'cache.db';
