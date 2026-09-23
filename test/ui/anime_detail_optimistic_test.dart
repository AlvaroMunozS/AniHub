import 'dart:async';

import 'package:anihub/domain/entities/entry.dart';
import 'package:anihub/domain/values/watch_status.dart';
import 'package:anihub/ui/router.dart';
import 'package:anihub/ui/screens/anime_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/controllable_repository.dart';
import 'support/pump_app.dart';

/// Pumps the detail screen of Frieren, saved in the library with [status].
///
/// Saves wait for [saveGate] when it is set.
Future<GoRouter> _pumpDetail(
  WidgetTester tester, {
  required WatchStatus status,
  bool failSave = false,
  bool failDelete = false,
  Completer<void>? saveGate,
}) {
  final ControllableRepository repo =
      ControllableRepository(<Entry>[
          Entry(
            id: 'e-1',
            malId: 52991,
            title: 'Sousou no Frieren',
            status: status,
            totalEpisodes: 28,
            updatedAt: DateTime(2024),
          ),
        ])
        ..failSave = failSave
        ..failDelete = failDelete
        ..saveGate = saveGate;
  addTearDown(repo.dispose);
  return pumpApp(
    tester,
    repo: repo,
    initialLocation: RoutePaths.animeDetail(52991),
  );
}

/// Scopes a text finder to the detail screen, excluding the shell around it.
Finder _inDetail(String text) => find.descendant(
  of: find.byType(AnimeDetailScreen),
  matching: find.text(text),
);

/// A collapsed `StatusSelector` keeps every status in the tree, hiding the
/// others with opacity, so tests check opacity instead of presence.
double _opacityOf(WidgetTester tester, Finder textFinder) {
  final Finder opacity = find
      .ancestor(of: textFinder, matching: find.byType(Opacity))
      .first;
  return tester.widget<Opacity>(opacity).opacity;
}

// The repository never re-emits, so every change these tests observe can
// only come from the optimistic layer.
void main() {
  testWidgets('shows a status change before the stream confirms it', (
    WidgetTester tester,
  ) async {
    await _pumpDetail(tester, status: WatchStatus.watching);

    await tester.tap(_inDetail('Viendo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Completado').last);
    await tester.pumpAndSettle();

    expect(_opacityOf(tester, _inDetail('Completado')), 1);
    expect(_opacityOf(tester, _inDetail('Viendo')), 0);
  });

  testWidgets('rolls back a failed status change and reports it', (
    WidgetTester tester,
  ) async {
    await _pumpDetail(tester, status: WatchStatus.watching, failSave: true);

    await tester.tap(_inDetail('Viendo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Completado').last);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isA<StateError>());
    expect(_opacityOf(tester, _inDetail('Viendo')), 1);
    expect(_opacityOf(tester, _inDetail('Completado')), 0);
    expect(find.text('No se pudo actualizar'), findsOneWidget);
  });

  testWidgets('keeps the add button when adding to the library fails', (
    WidgetTester tester,
  ) async {
    final ControllableRepository repo = ControllableRepository(<Entry>[])
      ..failSave = true;
    addTearDown(repo.dispose);
    await pumpApp(
      tester,
      repo: repo,
      initialLocation: RoutePaths.animeDetail(52991),
    );

    await tester.tap(_inDetail('Añadir'));
    await tester.pumpAndSettle();
    await tester.tap(_inDetail('Pendiente'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isA<StateError>());
    expect(_opacityOf(tester, _inDetail('Añadir')), 1);
    expect(_opacityOf(tester, _inDetail('Pendiente')), 0);
    expect(find.text('No se pudo añadir'), findsOneWidget);
  });

  testWidgets('removing from a detail opened directly goes to the library', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await _pumpDetail(
      tester,
      status: WatchStatus.watching,
    );

    await tester.tap(find.byTooltip('Eliminar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Eliminar'));
    await tester.pumpAndSettle();

    expect(find.byType(AnimeDetailScreen), findsNothing);
    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      RoutePaths.library,
    );
  });

  testWidgets('restores the entry when removal fails and reports it', (
    WidgetTester tester,
  ) async {
    await _pumpDetail(tester, status: WatchStatus.watching, failDelete: true);

    await tester.tap(find.byTooltip('Eliminar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Eliminar'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isA<StateError>());
    expect(find.byTooltip('Eliminar'), findsOneWidget);
    expect(find.byType(AnimeDetailScreen), findsOneWidget);
    expect(find.text('No se pudo eliminar'), findsOneWidget);
  });

  testWidgets('shows a favorite change before the stream confirms it', (
    WidgetTester tester,
  ) async {
    await _pumpDetail(tester, status: WatchStatus.completed);

    await tester.tap(find.byTooltip('Añadir a favoritos'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Quitar de favoritos'), findsOneWidget);
    expect(find.byTooltip('Añadir a favoritos'), findsNothing);
  });

  testWidgets('ignores a second favorite tap while the first is saving', (
    WidgetTester tester,
  ) async {
    final Completer<void> gate = Completer<void>();
    await _pumpDetail(tester, status: WatchStatus.completed, saveGate: gate);

    await tester.tap(find.byTooltip('Añadir a favoritos'));
    await tester.pump();
    await tester.tap(find.byTooltip('Quitar de favoritos'));
    await tester.pump();
    gate.complete();
    await tester.pumpAndSettle();

    expect(find.text('No se pudo actualizar'), findsNothing);
    expect(find.byTooltip('Quitar de favoritos'), findsOneWidget);
  });

  testWidgets('rolls back a failed favorite change and reports it', (
    WidgetTester tester,
  ) async {
    await _pumpDetail(tester, status: WatchStatus.completed, failSave: true);

    await tester.tap(find.byTooltip('Añadir a favoritos'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isA<StateError>());
    expect(find.byTooltip('Añadir a favoritos'), findsOneWidget);
    expect(find.byTooltip('Quitar de favoritos'), findsNothing);
    expect(find.text('No se pudo actualizar'), findsOneWidget);
  });
}
