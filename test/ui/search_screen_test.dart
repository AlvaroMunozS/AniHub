import 'package:anihub/domain/entities/entry.dart';
import 'package:anihub/domain/errors/catalog_exception.dart';
import 'package:anihub/domain/ports/anime_catalog.dart';
import 'package:anihub/domain/ports/entry_repository.dart';
import 'package:anihub/domain/values/watch_status.dart';

import 'package:anihub/ui/router.dart';
import 'package:anihub/ui/screens/anime_detail_screen.dart';
import 'package:anihub/ui/widgets/catalog_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_anime_catalog.dart';
import 'support/pump_app.dart';

/// Past the search debounce.
const Duration _debounce = Duration(milliseconds: 400);

Future<void> _pumpSearch(
  WidgetTester tester, {
  required AnimeCatalog catalog,
  EntryRepository? repo,
}) {
  return pumpApp(
    tester,
    repo: repo,
    catalog: catalog,
    initialLocation: RoutePaths.search,
  );
}

Future<void> _search(WidgetTester tester, String query) async {
  await tester.enterText(find.byType(TextField), query);
  await tester.pump(_debounce);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows results as posters that open their detail screen', (
    WidgetTester tester,
  ) async {
    await _pumpSearch(tester, catalog: FakeAnimeCatalog());

    await _search(tester, 'One Piece');

    expect(find.widgetWithText(CatalogCard, 'One Piece'), findsOneWidget);

    await tester.tap(find.byType(CatalogCard));
    await tester.pumpAndSettle();

    expect(find.byType(AnimeDetailScreen), findsOneWidget);
  });

  testWidgets('labels results that are already in the library', (
    WidgetTester tester,
  ) async {
    await _pumpSearch(
      tester,
      catalog: FakeAnimeCatalog(),
      repo: inMemoryLibrary(<Entry>[
        Entry(
          malId: 21,
          title: 'One Piece',
          status: WatchStatus.planned,
          updatedAt: DateTime(2024),
        ),
      ]),
    );

    await _search(tester, 'One Piece');

    expect(find.text('En biblioteca'), findsOneWidget);
  });

  testWidgets('shows the rate limit wait instead of an empty result', (
    WidgetTester tester,
  ) async {
    await _pumpSearch(
      tester,
      catalog: FakeAnimeCatalog(
        error: const CatalogRateLimitException(
          retryAfter: Duration(seconds: 30),
        ),
      ),
    );

    await _search(tester, 'Frieren');

    expect(
      find.text(
        'Demasiadas peticiones a MyAnimeList; espera unos 30 segundos.',
      ),
      findsOneWidget,
    );
    expect(find.text('Sin resultados'), findsNothing);
  });

  testWidgets('asks to wait a few seconds for a rate limit of one second', (
    WidgetTester tester,
  ) async {
    await _pumpSearch(
      tester,
      catalog: FakeAnimeCatalog(
        error: const CatalogRateLimitException(
          retryAfter: Duration(seconds: 1),
        ),
      ),
    );

    await _search(tester, 'Frieren');

    expect(
      find.text('Demasiadas peticiones a MyAnimeList; espera unos segundos.'),
      findsOneWidget,
    );
  });

  testWidgets('explains that the build has no valid client id', (
    WidgetTester tester,
  ) async {
    await _pumpSearch(
      tester,
      catalog: FakeAnimeCatalog(
        error: const CatalogUnauthorizedException('missing'),
      ),
    );

    await _search(tester, 'Frieren');

    expect(find.text(spanish.catalogUnauthorized), findsOneWidget);
  });

  testWidgets('reports an unexpected search failure', (
    WidgetTester tester,
  ) async {
    await _pumpSearch(
      tester,
      catalog: FakeAnimeCatalog(error: StateError('bug')),
    );

    await _search(tester, 'Frieren');

    expect(tester.takeException(), isA<StateError>());
    expect(find.text('No se pudo buscar'), findsOneWidget);
    expect(find.text(spanish.catalogRetryLater), findsOneWidget);
  });

  testWidgets('asks to check the connection when the network fails', (
    WidgetTester tester,
  ) async {
    await _pumpSearch(
      tester,
      catalog: FakeAnimeCatalog(error: const CatalogNetworkException('down')),
    );

    await _search(tester, 'Frieren');

    expect(find.text('No se pudo buscar'), findsOneWidget);
    expect(
      find.text('Revisa la conexión e inténtalo otra vez.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
  });

  testWidgets('says so when nothing matches the query', (
    WidgetTester tester,
  ) async {
    await _pumpSearch(tester, catalog: FakeAnimeCatalog());

    await _search(tester, 'no such anime');

    expect(find.text('Sin resultados'), findsOneWidget);
    expect(find.text('No hay nada para «no such anime».'), findsOneWidget);
  });

  testWidgets('does not search fewer than three characters', (
    WidgetTester tester,
  ) async {
    await _pumpSearch(
      tester,
      catalog: FakeAnimeCatalog(error: const CatalogNetworkException('down')),
    );

    await _search(tester, 'Fr');

    expect(find.text('No se pudo buscar'), findsNothing);
    expect(find.textContaining('al menos tres letras'), findsOneWidget);
  });
}
