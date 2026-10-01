import 'dart:async';

import 'package:anihub/application/usecases/usecases.dart';
import 'package:anihub/domain/entities/catalog_anime.dart';
import 'package:anihub/domain/errors/catalog_exception.dart';
import 'package:anihub/domain/ports/anime_catalog.dart';
import 'package:anihub/domain/values/anime_season.dart';
import 'package:anihub/domain/values/broadcast.dart';
import 'package:anihub/ui/providers.dart';
import 'package:anihub/ui/router.dart';
import 'package:anihub/ui/widgets/airing/airing_view.dart';
import 'package:anihub/ui/widgets/catalog_card.dart';
import 'package:anihub/ui/widgets/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_anime_catalog.dart';
import 'support/pump_app.dart';

/// Thursday 24 September 2026, in summer.
final DateTime _now = DateTime(2026, 9, 24, 12);

List<Override> _at(DateTime Function() now) => <Override>[
  clockProvider.overrideWithValue(now),
  scheduleAiringProvider.overrideWithValue(
    ScheduleAiring(localOffset: (DateTime utc) => const Duration(hours: 2)),
  ),
];

const List<CatalogAnime> _airing = <CatalogAnime>[
  CatalogAnime(
    malId: 102,
    title: 'Gachiakuta',
    broadcast: Broadcast(weekday: DateTime.thursday, hour: 22, minute: 0),
  ),
];

/// Dandadan is listed in every season, Upcoming only in the next one and
/// Niche in none.
const List<CatalogAnime> _premieres = <CatalogAnime>[
  CatalogAnime(malId: 201, title: 'Dandadan', memberCount: 900000),
  CatalogAnime(malId: 202, title: 'Upcoming', memberCount: 3000),
  CatalogAnime(malId: 203, title: 'Niche', memberCount: 500),
];

/// Premieres that stay loading until [pending] completes.
class _PendingCatalog extends FakeAnimeCatalog {
  _PendingCatalog() : super(airing: _airing);

  final Completer<List<CatalogAnime>> pending = Completer<List<CatalogAnime>>();

  @override
  Future<List<CatalogAnime>> premieringIn(int year, AnimeSeason season) {
    premiereRequests.add((year, season));
    return pending.future;
  }
}

FakeAnimeCatalog _catalog({List<CatalogAnime> premieres = _premieres}) =>
    FakeAnimeCatalog(airing: _airing, premieres: premieres);

Future<void> _pumpBrowse(
  WidgetTester tester, {
  required AnimeCatalog catalog,
  DateTime Function()? now,
}) {
  return pumpApp(
    tester,
    catalog: catalog,
    initialLocation: RoutePaths.search,
    overrides: _at(now ?? () => _now),
  );
}

Future<void> _tapTooltip(WidgetTester tester, String tooltip) async {
  await tester.tap(find.byTooltip(tooltip));
  await tester.pumpAndSettle();
}

Future<void> _previous(WidgetTester tester) =>
    _tapTooltip(tester, spanish.searchSeasonPrevious);

Future<void> _next(WidgetTester tester) =>
    _tapTooltip(tester, spanish.searchSeasonNext);

Future<void> _resume(WidgetTester tester) async {
  for (final AppLifecycleState state in <AppLifecycleState>[
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('steps back to a season shown in one ranked grid', (
    WidgetTester tester,
  ) async {
    final FakeAnimeCatalog catalog = _catalog();
    await _pumpBrowse(tester, catalog: catalog);

    await _previous(tester);

    expect(find.text('Primavera 2026'), findsOneWidget);
    expect(find.byType(Tab), findsNothing);
    expect(find.widgetWithText(CatalogCard, 'Dandadan'), findsOneWidget);
    expect(find.widgetWithText(CatalogCard, 'Upcoming'), findsNothing);
    expect(find.text('1 serie'), findsOneWidget);
    expect(catalog.premiereRequests, <(int, AnimeSeason)>[
      (2026, AnimeSeason.spring),
    ]);
  });

  testWidgets('keeps going back without a limit', (WidgetTester tester) async {
    await _pumpBrowse(tester, catalog: _catalog());

    for (int i = 0; i < 5; i++) {
      await _previous(tester);
    }

    expect(find.text('Primavera 2025'), findsOneWidget);
  });

  testWidgets('goes one season forward at most, with a lower threshold', (
    WidgetTester tester,
  ) async {
    await _pumpBrowse(tester, catalog: _catalog());

    await _next(tester);

    expect(find.text('Otoño 2026'), findsOneWidget);
    expect(find.widgetWithText(CatalogCard, 'Upcoming'), findsOneWidget);
    expect(find.widgetWithText(CatalogCard, 'Niche'), findsNothing);
    expect(find.text('2 series'), findsOneWidget);
    final IconButton next = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.chevron_right),
    );
    expect(next.onPressed, isNull);
  });

  testWidgets('returns to the current season from its name', (
    WidgetTester tester,
  ) async {
    await _pumpBrowse(tester, catalog: _catalog());
    await _previous(tester);

    await tester.tap(find.text('Primavera 2026'));
    await tester.pumpAndSettle();

    expect(find.text('Verano 2026'), findsOneWidget);
    expect(find.byType(Tab), findsNWidgets(DateTime.daysPerWeek));
    expect(find.text('1 en emisión'), findsOneWidget);
  });

  testWidgets('requests each season once per session', (
    WidgetTester tester,
  ) async {
    final FakeAnimeCatalog catalog = _catalog();
    await _pumpBrowse(tester, catalog: catalog);

    await _previous(tester);
    await _next(tester);
    await _previous(tester);

    expect(catalog.premiereRequests, hasLength(1));
    expect(catalog.airingRequests, hasLength(1));
  });

  testWidgets('keeps the arrows while a season loads', (
    WidgetTester tester,
  ) async {
    final _PendingCatalog catalog = _PendingCatalog();
    await _pumpBrowse(tester, catalog: catalog);

    await tester.tap(find.byTooltip(spanish.searchSeasonPrevious));
    await tester.pump();

    expect(find.text('Primavera 2026'), findsOneWidget);
    expect(find.byType(Skeleton), findsWidgets);
    expect(find.byTooltip(spanish.searchSeasonNext), findsOneWidget);

    catalog.pending.complete(_premieres);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(CatalogCard, 'Dandadan'), findsOneWidget);
  });

  testWidgets('keeps the arrows when a season fails and retries it', (
    WidgetTester tester,
  ) async {
    final FakeAnimeCatalog catalog = _catalog()
      ..premiereError = const CatalogNetworkException('down');
    await _pumpBrowse(tester, catalog: catalog);

    await _previous(tester);

    expect(find.text(spanish.searchAiringFailed), findsOneWidget);
    expect(find.text('Primavera 2026'), findsOneWidget);

    catalog.premiereError = null;
    await tester.tap(find.text(spanish.commonRetry));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(CatalogCard, 'Dandadan'), findsOneWidget);

    await _next(tester);
    expect(find.text('Verano 2026'), findsOneWidget);
  });

  testWidgets('says so when a season has nothing', (WidgetTester tester) async {
    await _pumpBrowse(
      tester,
      catalog: _catalog(premieres: const <CatalogAnime>[]),
    );

    await _previous(tester);

    expect(find.text(spanish.searchSeasonEmptyTitle), findsOneWidget);
  });

  testWidgets('keeps the grid when a refresh of another season fails', (
    WidgetTester tester,
  ) async {
    final FakeAnimeCatalog catalog = _catalog();
    await _pumpBrowse(tester, catalog: catalog);
    await _previous(tester);

    catalog.premiereError = const CatalogNetworkException('down');
    await tester.drag(
      find.widgetWithText(CatalogCard, 'Dandadan'),
      const Offset(0, 400),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(CatalogCard, 'Dandadan'), findsOneWidget);
    expect(
      find.widgetWithText(SnackBar, 'Revisa la conexión e inténtalo otra vez.'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 30));
    expect(catalog.premiereRequests, hasLength(2));
  });

  testWidgets('stays one season back when the season changes on resume', (
    WidgetTester tester,
  ) async {
    DateTime now = DateTime(2026, 9, 30, 12);
    await _pumpBrowse(tester, catalog: _catalog(), now: () => now);
    await _previous(tester);
    expect(find.text('Primavera 2026'), findsOneWidget);

    now = DateTime(2026, 10, 1, 12);
    await _resume(tester);

    expect(find.text('Verano 2026'), findsOneWidget);
    expect(find.byType(Tab), findsNothing);
  });

  testWidgets('comes back on the same season after a search', (
    WidgetTester tester,
  ) async {
    await _pumpBrowse(tester, catalog: _catalog());
    await _previous(tester);

    await tester.enterText(find.byType(TextField), 'One Piece');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.byType(AiringView), findsNothing);

    await tester.tap(find.byTooltip(spanish.searchBarClear));
    await tester.pumpAndSettle();

    expect(find.text('Primavera 2026'), findsOneWidget);
  });
}
