import 'dart:async';

import 'package:anihub/domain/entities/entry.dart';
import 'package:anihub/domain/errors/backup_format_exception.dart';
import 'package:anihub/domain/ports/library_backup_source.dart';
import 'package:anihub/domain/values/watch_status.dart';
import 'package:anihub/ui/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../support/in_memory_entry_repository.dart';
import 'support/fake_library_backup_source.dart';
import 'support/pump_app.dart';

Entry _entry({required int malId, required String title, DateTime? updatedAt}) {
  return Entry(
    malId: malId,
    title: title,
    status: WatchStatus.planned,
    updatedAt: updatedAt ?? DateTime(2024),
  );
}

/// Returns the entries passed to [completer] once it completes, so a test
/// can act while the file is being picked.
class _PendingBackupSource implements LibraryBackupSource {
  final Completer<List<Entry>?> completer = Completer<List<Entry>?>();

  @override
  Future<List<Entry>?> pickLibrary() => completer.future;
}

Future<GoRouter> _pumpMore(
  WidgetTester tester, {
  InMemoryEntryRepository? repo,
  LibraryBackupSource? backupSource,
}) {
  return pumpApp(
    tester,
    repo: repo,
    backupSource: backupSource,
    initialLocation: RoutePaths.more,
  );
}

Future<void> _import(WidgetTester tester) async {
  await tester.tap(find.text('Importar biblioteca'));
  await tester.pump();
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'AniHub',
      packageName: 'com.example.anihub',
      version: '1.2.3',
      buildNumber: '4',
      buildSignature: '',
    );
  });

  testWidgets('shows the version and credits MyAnimeList', (
    WidgetTester tester,
  ) async {
    await _pumpMore(tester);

    expect(find.text('Versión 1.2.3 · Datos de MyAnimeList'), findsOneWidget);

    await tester.tap(find.text('Acerca de'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('no está afiliada a MyAnimeList'),
      findsOneWidget,
    );
    expect(find.text('Ver licencias'), findsOneWidget);
  });

  testWidgets('imports the picked file and reports a summary', (
    WidgetTester tester,
  ) async {
    final InMemoryEntryRepository repo = inMemoryLibrary(<Entry>[
      _entry(malId: 1, title: 'Unchanged', updatedAt: DateTime(2024, 6)),
    ]);

    await _pumpMore(
      tester,
      repo: repo,
      backupSource: FakeLibraryBackupSource(
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

    await _pumpMore(
      tester,
      repo: repo,
      backupSource: const FakeLibraryBackupSource(
        error: BackupFormatException('invalid format'),
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
    await _pumpMore(
      tester,
      backupSource: FakeLibraryBackupSource(error: StateError('read failed')),
    );
    await _import(tester);

    expect(tester.takeException(), isA<StateError>());
    expect(find.text('No se pudo importar la biblioteca'), findsOneWidget);
  });

  testWidgets('finishes an import after the user leaves the screen', (
    WidgetTester tester,
  ) async {
    final InMemoryEntryRepository repo = inMemoryLibrary();
    final _PendingBackupSource source = _PendingBackupSource();
    final GoRouter router = await _pumpMore(
      tester,
      repo: repo,
      backupSource: source,
    );

    await tester.tap(find.text('Importar biblioteca'));
    await tester.pump();
    router.go(RoutePaths.library);
    await tester.pumpAndSettle();
    source.completer.complete(<Entry>[_entry(malId: 2, title: 'New')]);
    await tester.pumpAndSettle();

    expect(await repo.findAll(), hasLength(1));
  });

  testWidgets('does nothing when the file pick is cancelled', (
    WidgetTester tester,
  ) async {
    final InMemoryEntryRepository repo = inMemoryLibrary();

    await _pumpMore(tester, repo: repo);
    await _import(tester);

    expect(find.byType(SnackBar), findsNothing);
    expect(await repo.findAll(), isEmpty);
  });
}
