import 'dart:async';

import 'package:anihub/domain/entities/entry.dart';
import 'package:anihub/domain/values/watch_status.dart';
import 'package:anihub/ui/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/controllable_repository.dart';
import 'support/pump_app.dart';

Entry _completed({required bool isFavorite}) {
  return Entry(
    id: 'e1',
    malId: 5114,
    title: 'Fullmetal Alchemist',
    status: WatchStatus.completed,
    updatedAt: DateTime(2024),
    isFavorite: isFavorite,
  );
}

final String _completedTab = RoutePaths.libraryFor(WatchStatus.completed);

/// Turns on the favorites filter from the options sheet, then dismisses the
/// sheet by tapping outside it.
Future<void> _filterOnlyFavorites(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.filter_list));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Solo favoritos'));
  await tester.pumpAndSettle();
  await tester.tapAt(const Offset(20, 20));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'unfavoriting hides the entry from the favorites filter before the '
    'write completes',
    (WidgetTester tester) async {
      final ControllableRepository repo = ControllableRepository(<Entry>[
        _completed(isFavorite: true),
      ])..saveGate = Completer<void>();
      addTearDown(repo.dispose);

      await pumpApp(tester, repo: repo, initialLocation: _completedTab);
      await _filterOnlyFavorites(tester);
      expect(find.text('Fullmetal Alchemist'), findsOneWidget);

      await tester.tap(find.text('Fullmetal Alchemist'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Quitar de favoritos'));
      await tester.pump();

      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();

      // `saveGate` is still pending, so the entry was hidden optimistically.
      expect(find.text('Fullmetal Alchemist'), findsNothing);

      repo.saveGate!.complete();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'restores the entry in the favorites filter when the write fails',
    (WidgetTester tester) async {
      final ControllableRepository repo = ControllableRepository(<Entry>[
        _completed(isFavorite: true),
      ])..failSave = true;
      addTearDown(repo.dispose);

      await pumpApp(tester, repo: repo, initialLocation: _completedTab);
      await _filterOnlyFavorites(tester);

      await tester.tap(find.text('Fullmetal Alchemist'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Quitar de favoritos'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isA<StateError>());
      expect(find.text('No se pudo actualizar'), findsOneWidget);

      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();

      expect(find.text('Fullmetal Alchemist'), findsOneWidget);
    },
  );

  testWidgets('shows an empty state when no favorites match', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      repo: inMemoryLibrary(<Entry>[_completed(isFavorite: false)]),
      initialLocation: _completedTab,
    );
    await _filterOnlyFavorites(tester);

    expect(find.text('Fullmetal Alchemist'), findsNothing);
    expect(find.text('No tienes favoritos en Completado.'), findsOneWidget);
  });

  testWidgets('names the filter button as active while filtering favorites', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      repo: inMemoryLibrary(<Entry>[_completed(isFavorite: true)]),
      initialLocation: _completedTab,
    );
    expect(find.byTooltip('Filtrar y ordenar'), findsOneWidget);

    await _filterOnlyFavorites(tester);

    expect(find.byTooltip('Filtrar y ordenar (filtro activo)'), findsOneWidget);
  });

  testWidgets('offers the favorites filter only on the completed tab', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.filter_list));
    await tester.pumpAndSettle();

    expect(find.text('Ordenar'), findsOneWidget);
    expect(find.text('Solo favoritos'), findsNothing);
  });
}
