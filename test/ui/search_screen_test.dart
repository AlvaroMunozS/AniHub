import 'package:anihub/application/usecases/usecases.dart';
import 'package:anihub/domain/entities/catalog_anime.dart';
import 'package:anihub/domain/entities/entry.dart';
import 'package:anihub/domain/errors/catalog_exception.dart';
import 'package:anihub/domain/ports/anime_catalog.dart';
import 'package:anihub/domain/ports/entry_repository.dart';
import 'package:anihub/domain/values/anime_season.dart';
import 'package:anihub/domain/values/broadcast.dart';
import 'package:anihub/domain/values/watch_status.dart';
import 'package:anihub/ui/providers.dart';
import 'package:anihub/ui/router.dart';
import 'package:anihub/ui/screens/anime_detail_screen.dart';
import 'package:anihub/ui/shell/content_column.dart';
import 'package:anihub/ui/theme/app_theme.dart';
import 'package:anihub/ui/widgets/airing/airing_view.dart';
import 'package:anihub/ui/widgets/catalog_card.dart';
import 'package:anihub/ui/widgets/pill_search_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_anime_catalog.dart';
import 'support/pump_app.dart';

/// Past the search debounce.
const Duration _debounce = Duration(milliseconds: 400);

/// Thursday 24 September 2026, in summer.
final DateTime _now = DateTime(2026, 9, 24, 12);

/// Fixes the clock at [_now] and the local time zone at UTC+2.
final List<Override> _madridThursday = <Override>[
  clockProvider.overrideWithValue(() => _now),
  scheduleAiringProvider.overrideWithValue(
    ScheduleAiring(localOffset: (DateTime utc) => const Duration(hours: 2)),
  ),
];

/// In local time: Kaiju on Wednesday at 17:30, Gachiakuta on Thursday at
/// 15:00, Frieren on Friday at 16:00 and Web Series without a slot.
const List<CatalogAnime> _airing = <CatalogAnime>[
  CatalogAnime(
    malId: 101,
    title: 'Kaiju',
    broadcast: Broadcast(weekday: DateTime.thursday, hour: 0, minute: 30),
  ),
  CatalogAnime(
    malId: 102,
    title: 'Gachiakuta',
    broadcast: Broadcast(weekday: DateTime.thursday, hour: 22, minute: 0),
  ),
  CatalogAnime(
    malId: 52991,
    title: 'Sousou no Frieren',
    broadcast: Broadcast(weekday: DateTime.friday, hour: 23, minute: 0),
  ),
  CatalogAnime(malId: 104, title: 'Web Series'),
];

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
    overrides: _madridThursday,
  );
}

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.widgetWithText(Tab, label));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(Tab, label));
  await tester.pumpAndSettle();
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
    expect(find.byType(AiringView), findsOneWidget);
  });

  testWidgets('searches from the minimum length of the catalog', (
    WidgetTester tester,
  ) async {
    await _pumpSearch(tester, catalog: FakeAnimeCatalog(minQueryLength: 2));

    await _search(tester, 'O');
    expect(find.byType(AiringView), findsOneWidget);

    await _search(tester, 'On');

    expect(find.widgetWithText(CatalogCard, 'One Piece'), findsOneWidget);
  });

  testWidgets('keeps the search bar within the content width', (
    WidgetTester tester,
  ) async {
    await _pumpSearch(tester, catalog: FakeAnimeCatalog());
    tester.view.physicalSize =
        const Size(1600, 900) * tester.view.devicePixelRatio;
    await tester.pumpAndSettle();

    final Rect bar = tester.getRect(find.byType(PillSearchBar));
    expect(
      bar.width,
      lessThanOrEqualTo(AppLayout.contentMaxWidth + ContentColumn.gutter * 2),
    );
    expect(bar.center.dx, moreOrLessEquals(800));
  });

  group('airing', () {
    testWidgets('shows the current season', (WidgetTester tester) async {
      final FakeAnimeCatalog catalog = FakeAnimeCatalog(airing: _airing);

      await _pumpSearch(tester, catalog: catalog);

      expect(catalog.airingRequests, <(int, AnimeSeason)>[
        (2026, AnimeSeason.summer),
      ]);
      expect(find.text('Verano 2026'), findsOneWidget);
      expect(find.text('4 en emisión'), findsOneWidget);
    });

    testWidgets('opens on today with the local broadcast times', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await _pumpSearch(tester, catalog: FakeAnimeCatalog(airing: _airing));

      expect(find.bySemanticsLabel(RegExp('^jue, hoy')), findsOneWidget);
      expect(find.widgetWithText(CatalogCard, 'Gachiakuta'), findsOneWidget);
      expect(find.text('15:00'), findsOneWidget);
      expect(
        find.widgetWithText(CatalogCard, 'Sousou no Frieren'),
        findsNothing,
      );
      semantics.dispose();
    });

    testWidgets('moves a late-night slot in Japan to the previous day', (
      WidgetTester tester,
    ) async {
      await _pumpSearch(tester, catalog: FakeAnimeCatalog(airing: _airing));

      expect(find.widgetWithText(CatalogCard, 'Kaiju'), findsNothing);

      await _openTab(tester, 'mié');

      expect(find.widgetWithText(CatalogCard, 'Kaiju'), findsOneWidget);
      expect(find.text('17:30'), findsOneWidget);
    });

    testWidgets('lists anime without a fixed slot in a last tab', (
      WidgetTester tester,
    ) async {
      await _pumpSearch(tester, catalog: FakeAnimeCatalog(airing: _airing));

      await _openTab(tester, 'Otros');

      expect(find.widgetWithText(CatalogCard, 'Web Series'), findsOneWidget);
    });

    testWidgets('starts the week on the day picked in the settings', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        catalog: FakeAnimeCatalog(airing: _airing),
        initialLocation: RoutePaths.search,
        overrides: _madridThursday,
        prefs: const <String, Object>{'general.firstWeekday': 'sunday'},
      );

      final List<String> tabs = <String>[
        for (final Tab tab in tester.widgetList<Tab>(find.byType(Tab)))
          if (tab.text case final String text) text,
      ];
      expect(tabs.take(2), <String>['dom', 'lun']);
    });

    testWidgets('has no last tab when every anime has a slot', (
      WidgetTester tester,
    ) async {
      await _pumpSearch(
        tester,
        catalog: FakeAnimeCatalog(airing: _airing.take(3).toList()),
      );

      expect(find.widgetWithText(Tab, 'Otros'), findsNothing);
    });

    testWidgets('says so on a day without anime', (WidgetTester tester) async {
      await _pumpSearch(tester, catalog: FakeAnimeCatalog(airing: _airing));

      await _openTab(tester, 'lun');

      expect(find.text('Nada se emite este día'), findsOneWidget);
    });

    testWidgets('dims the anime already in the library', (
      WidgetTester tester,
    ) async {
      await _pumpSearch(
        tester,
        catalog: FakeAnimeCatalog(airing: _airing),
        repo: inMemoryLibrary(<Entry>[
          Entry(
            malId: 102,
            title: 'Gachiakuta',
            status: WatchStatus.watching,
            updatedAt: DateTime(2026),
          ),
        ]),
      );

      expect(find.text('En biblioteca'), findsOneWidget);
    });

    testWidgets('comes back on the same day after a search', (
      WidgetTester tester,
    ) async {
      await _pumpSearch(tester, catalog: FakeAnimeCatalog(airing: _airing));
      await _openTab(tester, 'vie');

      await _search(tester, 'One Piece');

      expect(find.byType(AiringView), findsNothing);
      expect(find.widgetWithText(CatalogCard, 'One Piece'), findsOneWidget);

      await tester.tap(find.byTooltip(spanish.searchBarClear));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(CatalogCard, 'Sousou no Frieren'),
        findsOneWidget,
      );
    });

    testWidgets('offers to retry when the season cannot load', (
      WidgetTester tester,
    ) async {
      final FakeAnimeCatalog catalog = FakeAnimeCatalog(
        airing: _airing,
        airingError: const CatalogNetworkException('down'),
      );
      await _pumpSearch(tester, catalog: catalog);

      expect(find.text('No se pudo cargar la temporada'), findsOneWidget);
      expect(
        find.text('Revisa la conexión e inténtalo otra vez.'),
        findsOneWidget,
      );

      catalog.airingError = null;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(CatalogCard, 'Gachiakuta'), findsOneWidget);
    });

    testWidgets('says so when nothing is airing', (WidgetTester tester) async {
      await _pumpSearch(
        tester,
        catalog: FakeAnimeCatalog(airing: const <CatalogAnime>[]),
      );

      expect(find.text('Nada en emisión'), findsOneWidget);
    });
  });
}
