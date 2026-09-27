import 'dart:async';

import 'package:anihub/domain/entities/entry.dart';
import 'package:anihub/domain/errors/backup_format_exception.dart';
import 'package:anihub/domain/ports/library_backups.dart';
import 'package:anihub/domain/values/watch_status.dart';
import 'package:anihub/ui/providers.dart';
import 'package:anihub/ui/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../support/fake_library_backups.dart';
import '../support/in_memory_entry_repository.dart';
import 'support/pump_app.dart';

final DateTime _now = DateTime(2026, 9, 27, 18);

Entry _entry({required int malId, required String title, DateTime? updatedAt}) {
  return Entry(
    malId: malId,
    title: title,
    status: WatchStatus.planned,
    updatedAt: updatedAt ?? DateTime(2024),
  );
}

/// Completes a pick with [picked] and a save with [saved] only when the test
/// says so, so it can act while a file dialog is open.
class _PendingBackups implements LibraryBackups {
  final Completer<List<Entry>?> picked = Completer<List<Entry>?>();
  final Completer<bool> saved = Completer<bool>();

  @override
  Future<List<Entry>?> pickLibrary() => picked.future;

  @override
  Future<bool> saveLibrary(
    List<Entry> entries, {
    required DateTime exportedAt,
  }) => saved.future;
}

Future<GoRouter> _pumpBackup(
  WidgetTester tester, {
  InMemoryEntryRepository? repo,
  LibraryBackups? backups,
}) {
  return pumpApp(
    tester,
    repo: repo,
    backups: backups,
    initialLocation: RoutePaths.backupSettings,
    overrides: <Override>[clockProvider.overrideWithValue(() => _now)],
  );
}

Future<void> _import(WidgetTester tester) async {
  await tester.tap(find.text('Importar biblioteca'));
  await tester.pump();
  await tester.pumpAndSettle();
}

Future<void> _export(WidgetTester tester) async {
  await tester.tap(find.text('Exportar biblioteca'));
  await tester.pump();
  await tester.pumpAndSettle();
}

ListTile _tile(WidgetTester tester, String title) {
  return tester.widget<ListTile>(
    find.ancestor(of: find.text(title), matching: find.byType(ListTile)),
  );
}

void main() {
  testWidgets('shows the export section above the restore section', (
    WidgetTester tester,
  ) async {
    await _pumpBackup(tester);

    expect(
      tester.getTopLeft(find.text('Exportar')).dy,
      lessThan(tester.getTopLeft(find.text('Restaurar')).dy),
    );
  });

  testWidgets('exports the library and reports how many anime it holds', (
    WidgetTester tester,
  ) async {
    final InMemoryEntryRepository repo = inMemoryLibrary(<Entry>[
      _entry(malId: 1, title: 'Frieren'),
      _entry(malId: 2, title: 'One Piece'),
    ]);
    final FakeLibraryBackups backups = FakeLibraryBackups(saveResult: true);

    await _pumpBackup(tester, repo: repo, backups: backups);
    await _export(tester);

    expect(find.text('Biblioteca exportada: 2 anime'), findsOneWidget);
    expect(backups.savedEntries, await repo.findAll());
    expect(backups.savedAt, _now);
  });

  testWidgets('says the library is empty without opening the save dialog', (
    WidgetTester tester,
  ) async {
    final FakeLibraryBackups backups = FakeLibraryBackups(saveResult: true);

    await _pumpBackup(tester, backups: backups);
    await _export(tester);

    expect(find.text('Tu biblioteca está vacía'), findsOneWidget);
    expect(backups.savedEntries, isNull);
  });

  testWidgets('does nothing when the save is cancelled', (
    WidgetTester tester,
  ) async {
    await _pumpBackup(
      tester,
      repo: inMemoryLibrary(<Entry>[_entry(malId: 1, title: 'Frieren')]),
    );
    await _export(tester);

    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('reports an export failure', (WidgetTester tester) async {
    await _pumpBackup(
      tester,
      repo: inMemoryLibrary(<Entry>[_entry(malId: 1, title: 'Frieren')]),
      backups: FakeLibraryBackups(saveError: StateError('write failed')),
    );
    await _export(tester);

    expect(tester.takeException(), isA<StateError>());
    expect(find.text('No se pudo exportar la biblioteca'), findsOneWidget);
  });

  testWidgets('finishes an export after the user leaves the screen', (
    WidgetTester tester,
  ) async {
    final _PendingBackups backups = _PendingBackups();
    final GoRouter router = await _pumpBackup(
      tester,
      repo: inMemoryLibrary(<Entry>[_entry(malId: 1, title: 'Frieren')]),
      backups: backups,
    );

    await tester.tap(find.text('Exportar biblioteca'));
    await tester.pump();
    router.go(RoutePaths.library);
    await tester.pumpAndSettle();
    backups.saved.complete(true);
    await tester.pumpAndSettle();

    expect(find.text('Biblioteca exportada: 1 anime'), findsOneWidget);
  });

  testWidgets('disables both actions while one is running', (
    WidgetTester tester,
  ) async {
    final _PendingBackups backups = _PendingBackups();
    await _pumpBackup(
      tester,
      repo: inMemoryLibrary(<Entry>[_entry(malId: 1, title: 'Frieren')]),
      backups: backups,
    );

    await tester.tap(find.text('Exportar biblioteca'));
    await tester.pump();

    expect(_tile(tester, 'Exportar biblioteca').onTap, isNull);
    expect(_tile(tester, 'Importar biblioteca').onTap, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    backups.saved.complete(false);
    await tester.pumpAndSettle();

    expect(_tile(tester, 'Exportar biblioteca').onTap, isNotNull);
    expect(_tile(tester, 'Importar biblioteca').onTap, isNotNull);
  });

  testWidgets('imports the picked file and reports a summary', (
    WidgetTester tester,
  ) async {
    final InMemoryEntryRepository repo = inMemoryLibrary(<Entry>[
      _entry(malId: 1, title: 'Unchanged', updatedAt: DateTime(2024, 6)),
    ]);

    await _pumpBackup(
      tester,
      repo: repo,
      backups: FakeLibraryBackups(
        entries: <Entry>[
          _entry(malId: 1, title: 'Unchanged', updatedAt: DateTime(2024)),
          _entry(malId: 2, title: 'New', updatedAt: DateTime(2024, 6)),
        ],
      ),
    );
    await _import(tester);

    expect(
      find.text('Biblioteca importada: 1 nueva, 0 actualizadas, 1 sin cambios'),
      findsOneWidget,
    );
    expect(await repo.findAll(), hasLength(2));
  });

  testWidgets('reports an invalid file without touching the library', (
    WidgetTester tester,
  ) async {
    final InMemoryEntryRepository repo = inMemoryLibrary();

    await _pumpBackup(
      tester,
      repo: repo,
      backups: FakeLibraryBackups(
        error: const BackupFormatException('invalid format'),
      ),
    );
    await _import(tester);

    expect(
      find.text('El fichero no es una biblioteca de AniHub válida'),
      findsOneWidget,
    );
    expect(await repo.findAll(), isEmpty);
  });

  testWidgets('reports an unexpected import failure', (
    WidgetTester tester,
  ) async {
    await _pumpBackup(
      tester,
      backups: FakeLibraryBackups(error: StateError('read failed')),
    );
    await _import(tester);

    expect(tester.takeException(), isA<StateError>());
    expect(find.text('No se pudo importar la biblioteca'), findsOneWidget);
  });

  testWidgets('finishes an import after the user leaves the screen', (
    WidgetTester tester,
  ) async {
    final InMemoryEntryRepository repo = inMemoryLibrary();
    final _PendingBackups backups = _PendingBackups();
    final GoRouter router = await _pumpBackup(
      tester,
      repo: repo,
      backups: backups,
    );

    await tester.tap(find.text('Importar biblioteca'));
    await tester.pump();
    router.go(RoutePaths.library);
    await tester.pumpAndSettle();
    backups.picked.complete(<Entry>[_entry(malId: 2, title: 'New')]);
    await tester.pumpAndSettle();

    expect(await repo.findAll(), hasLength(1));
  });

  testWidgets('does nothing when the file pick is cancelled', (
    WidgetTester tester,
  ) async {
    final InMemoryEntryRepository repo = inMemoryLibrary();

    await _pumpBackup(tester, repo: repo);
    await _import(tester);

    expect(find.byType(SnackBar), findsNothing);
    expect(await repo.findAll(), isEmpty);
  });
}
