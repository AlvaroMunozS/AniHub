import 'package:anihub/infrastructure/cache/relations_store.dart';
import 'package:anihub/infrastructure/cache/relations_store_opener.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

class _MockDatabaseFactory extends Mock implements DatabaseFactory {}

class _CorruptDatabaseException extends DatabaseException {
  _CorruptDatabaseException() : super('file is not a database');

  @override
  Object? get result => null;

  @override
  int? getResultCode() => 26;
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

  Future<RelationsStore> open() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    return openRelationsStoreAt(
      factory,
      'cache.db',
      await SharedPreferences.getInstance(),
    );
  }

  test('starts with an empty store when cache.db cannot be opened', () async {
    when(() => factory.openDatabase(any(), options: any(named: 'options')))
        .thenThrow(StateError('cannot open'));

    final RelationsStore store = await open();

    expect(await store.loadAll(), isEmpty);
    await store.deleteSavedBefore(DateTime.utc(2026));
  });

  test('does not delete cache.db when the error is not corruption', () async {
    when(() => factory.openDatabase(any(), options: any(named: 'options')))
        .thenThrow(StateError('cannot open'));

    await open();

    verifyNever(() => factory.deleteDatabase(any()));
  });

  test(
    'starts with an empty store when a recreated cache.db fails too',
    () async {
      when(() => factory.openDatabase(any(), options: any(named: 'options')))
          .thenThrow(_CorruptDatabaseException());

      final RelationsStore store = await open();

      expect(await store.loadAll(), isEmpty);
      verify(() => factory.deleteDatabase('cache.db')).called(1);
      verify(() => factory.openDatabase(any(), options: any(named: 'options')))
          .called(2);
    },
  );
}
