import 'package:anihub/domain/entities/entry.dart';
import 'package:anihub/domain/ports/entry_repository.dart';
import 'package:anihub/domain/values/watch_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_app.dart';

/// Repository whose stream emits [entries], if any, and then fails.
class _FailingRepository implements EntryRepository {
  _FailingRepository([this.entries]);

  final List<Entry>? entries;
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
    if (entries != null) yield entries!;
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

  testWidgets('retries reading the library after an error', (
    WidgetTester tester,
  ) async {
    final _FailingRepository repo = _FailingRepository();

    await pumpApp(tester, repo: repo);

    expect(tester.takeException(), isStateError);
    expect(find.text('No se pudo leer la biblioteca'), findsOneWidget);
    final int before = repo.watchCalls;

    await tester.tap(find.widgetWithText(OutlinedButton, 'Reintentar'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isStateError);
    expect(repo.watchCalls, greaterThan(before));
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
