import 'package:anihub/domain/entities/entry.dart';
import 'package:anihub/domain/ports/entry_repository.dart';
import 'package:anihub/domain/values/watch_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_app.dart';

/// Repository whose stream emits [entries], if any, and then fails.
class _FailingRepository implements EntryRepository {
  _FailingRepository([this.entries]);

  /// Read on every subscription, so a test can let a retry load data.
  List<Entry>? entries;
  int watchCalls = 0;

  @override
  Future<List<Entry>> findAll() async => entries ?? <Entry>[];

  @override
  Future<Entry> save(Entry entry) async => entry;

  @override
  Future<void> delete(String id) async {}

  @override
  Future<void> upsertAll(List<Entry> entries) async {}

  @override
  Stream<List<Entry>> watchAll() async* {
    watchCalls++;
    final List<Entry>? loaded = entries;
    if (loaded != null) yield loaded;
    throw StateError('read failed');
  }
}

Entry _entry(int malId, String title, DateTime updatedAt) => Entry(
  id: 'id-$malId',
  malId: malId,
  title: title,
  status: WatchStatus.watching,
  updatedAt: updatedAt,
);

void main() {
  testWidgets('explains an empty library', (WidgetTester tester) async {
    await pumpApp(tester);

    expect(find.text('Tu biblioteca está vacía'), findsOneWidget);
  });

  testWidgets('reports a failing library once across retries', (
    WidgetTester tester,
  ) async {
    final _FailingRepository repo = _FailingRepository();

    await pumpApp(tester, repo: repo);

    expect(tester.takeException(), isStateError);
    expect(find.text('No se pudo leer la biblioteca'), findsOneWidget);
    final int before = repo.watchCalls;

    await tester.tap(find.widgetWithText(OutlinedButton, 'Reintentar'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(minutes: 1));

    expect(repo.watchCalls, greaterThan(before));
    expect(tester.takeException(), isNull);
    expect(find.text('No se pudo leer la biblioteca'), findsOneWidget);
  });

  testWidgets('reports a new failure after the library loads again', (
    WidgetTester tester,
  ) async {
    final _FailingRepository repo = _FailingRepository();

    await pumpApp(tester, repo: repo);
    expect(tester.takeException(), isStateError);

    repo.entries = <Entry>[_entry(1, 'Cowboy Bebop', DateTime(2024))];
    await tester.tap(find.widgetWithText(OutlinedButton, 'Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('Cowboy Bebop'), findsOneWidget);
    expect(tester.takeException(), isStateError);
  });

  testWidgets('keeps showing the last list when the stream fails', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      repo: _FailingRepository(<Entry>[
        _entry(1, 'Cowboy Bebop', DateTime(2024)),
      ]),
    );

    expect(tester.takeException(), isStateError);
    expect(find.text('Cowboy Bebop'), findsOneWidget);
    expect(
      find.textContaining('se muestra la última versión cargada'),
      findsOneWidget,
    );
    expect(find.text('No se pudo leer la biblioteca'), findsNothing);
  });
}
