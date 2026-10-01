import 'package:anihub/application/usecases/usecases.dart';
import 'package:anihub/domain/entities/catalog_anime.dart';
import 'package:anihub/domain/entities/entry.dart';
import 'package:anihub/domain/values/broadcast.dart';
import 'package:anihub/domain/values/watch_status.dart';
import 'package:anihub/ui/providers.dart';
import 'package:anihub/ui/router.dart';
import 'package:anihub/ui/widgets/catalog_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_anime_catalog.dart';
import '../support/in_memory_entry_repository.dart';
import 'support/pump_app.dart';

/// Thursday 24 September 2026, in summer.
final DateTime _now = DateTime(2026, 9, 24, 12);

/// Two hours ahead of UTC, so a Thursday evening slot in Japan stays on
/// Thursday afternoon.
final List<Override> _clock = <Override>[
  clockProvider.overrideWithValue(() => _now),
  scheduleAiringProvider.overrideWithValue(
    ScheduleAiring(localOffset: (DateTime utc) => const Duration(hours: 2)),
  ),
];

Broadcast _thursday(int hour) =>
    Broadcast(weekday: DateTime.thursday, hour: hour, minute: 0);

final List<CatalogAnime> _airing = <CatalogAnime>[
  CatalogAnime(
    malId: 301,
    title: 'Late mine',
    broadcast: _thursday(23),
    memberCount: 900000,
  ),
  CatalogAnime(
    malId: 302,
    title: 'Early mine',
    broadcast: _thursday(21),
    memberCount: 6000,
  ),
  CatalogAnime(
    malId: 303,
    title: 'Popular other',
    broadcast: _thursday(22),
    memberCount: 2000000,
  ),
  CatalogAnime(
    malId: 304,
    title: 'Niche mine',
    broadcast: _thursday(22),
    memberCount: 100,
  ),
  CatalogAnime(
    malId: 305,
    title: 'Niche planned',
    broadcast: _thursday(20),
    memberCount: 100,
  ),
  const CatalogAnime(
    malId: 306,
    title: 'Friday other',
    broadcast: Broadcast(weekday: DateTime.friday, hour: 22, minute: 0),
    memberCount: 50000,
  ),
];

Entry _entry(int malId, WatchStatus status) => Entry(
  malId: malId,
  title: 'Entry $malId',
  status: status,
  updatedAt: DateTime(2026, 9),
);

final List<Entry> _library = <Entry>[
  _entry(301, WatchStatus.watching),
  _entry(302, WatchStatus.watching),
  _entry(304, WatchStatus.watching),
  _entry(305, WatchStatus.planned),
];

Future<void> _pumpBrowse(
  WidgetTester tester, {
  List<CatalogAnime>? airing,
  List<CatalogAnime>? premieres,
  InMemoryEntryRepository? repo,
  Map<String, Object> prefs = const <String, Object>{},
}) {
  return pumpApp(
    tester,
    catalog: FakeAnimeCatalog(airing: airing ?? _airing, premieres: premieres),
    repo: repo ?? inMemoryLibrary(_library),
    prefs: prefs,
    initialLocation: RoutePaths.search,
    overrides: _clock,
  );
}

Finder get _chip => find.widgetWithText(FilterChip, spanish.searchAiringMine);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

List<CatalogCard> _cards(WidgetTester tester) =>
    tester.widgetList<CatalogCard>(find.byType(CatalogCard)).toList();

List<String> _titles(WidgetTester tester) => <String>[
  for (final CatalogCard card in _cards(tester)) card.anime.title,
];

void main() {
  testWidgets('shows only the series being watched, by broadcast time', (
    WidgetTester tester,
  ) async {
    await _pumpBrowse(tester);

    await _tap(tester, _chip);

    expect(_titles(tester), <String>['Early mine', 'Niche mine', 'Late mine']);
    expect(_cards(tester).any((CatalogCard c) => c.inLibrary), isFalse);
    expect(find.text('3 en emisión'), findsOneWidget);
  });

  testWidgets('lists a watched series in few lists, dimmed, unfiltered', (
    WidgetTester tester,
  ) async {
    await _pumpBrowse(tester);

    final CatalogCard niche = tester.widget<CatalogCard>(
      find.widgetWithText(CatalogCard, 'Niche mine'),
    );
    expect(niche.inLibrary, isTrue);
    expect(find.widgetWithText(CatalogCard, 'Niche planned'), findsNothing);
    expect(find.text('5 en emisión'), findsOneWidget);
  });

  testWidgets('says when none of your series airs on a day', (
    WidgetTester tester,
  ) async {
    await _pumpBrowse(tester);
    await _tap(tester, _chip);

    await _tap(tester, find.text('vie'));

    expect(find.text(spanish.searchAiringMineDayEmpty), findsOneWidget);
  });

  testWidgets('offers to show every series when none of yours airs', (
    WidgetTester tester,
  ) async {
    await _pumpBrowse(
      tester,
      repo: inMemoryLibrary(<Entry>[_entry(305, WatchStatus.planned)]),
    );
    await _tap(tester, _chip);

    expect(find.text(spanish.searchAiringMineEmptyTitle), findsOneWidget);
    await _tap(tester, find.text(spanish.searchAiringMineShowAll));

    expect(find.widgetWithText(CatalogCard, 'Popular other'), findsOneWidget);
    expect(tester.widget<FilterChip>(_chip).selected, isFalse);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('browse.airing.onlyMine'), isFalse);
  });

  testWidgets('hides the chip in other seasons and keeps the filter for the '
      'current one', (WidgetTester tester) async {
    await _pumpBrowse(
      tester,
      premieres: <CatalogAnime>[
        const CatalogAnime(malId: 301, title: 'Late mine', memberCount: 900000),
        const CatalogAnime(malId: 307, title: 'Past hit', memberCount: 800000),
      ],
    );
    await _tap(tester, _chip);

    await _tap(tester, find.byTooltip(spanish.searchSeasonPrevious));

    expect(_chip, findsNothing);
    expect(find.widgetWithText(CatalogCard, 'Past hit'), findsOneWidget);
    final CatalogCard mine = tester.widget<CatalogCard>(
      find.widgetWithText(CatalogCard, 'Late mine'),
    );
    expect(mine.inLibrary, isTrue);

    await _tap(tester, find.byTooltip(spanish.searchSeasonNext));

    expect(tester.widget<FilterChip>(_chip).selected, isTrue);
    expect(_titles(tester), <String>['Early mine', 'Niche mine', 'Late mine']);
  });

  testWidgets('opens filtered when the filter was left on', (
    WidgetTester tester,
  ) async {
    await _pumpBrowse(
      tester,
      prefs: <String, Object>{'browse.airing.onlyMine': true},
    );

    expect(_titles(tester), <String>['Early mine', 'Niche mine', 'Late mine']);
  });

  testWidgets('drops a series once it is no longer being watched', (
    WidgetTester tester,
  ) async {
    final InMemoryEntryRepository repo = inMemoryLibrary(_library);
    await _pumpBrowse(tester, repo: repo);
    await _tap(tester, _chip);

    final Entry late = (await repo.findAll()).firstWhere(
      (Entry e) => e.malId == 301,
    );
    await repo.save(late.withStatus(WatchStatus.completed));
    await tester.pumpAndSettle();

    expect(_titles(tester), <String>['Early mine', 'Niche mine']);
  });

  testWidgets('hides the chip when nothing airs this season', (
    WidgetTester tester,
  ) async {
    await _pumpBrowse(
      tester,
      airing: const <CatalogAnime>[],
      prefs: <String, Object>{'browse.airing.onlyMine': true},
    );

    expect(_chip, findsNothing);
    expect(find.text(spanish.searchAiringEmptyTitle), findsOneWidget);
  });

  testWidgets('fits the chip in the header with large text', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pumpBrowse(tester);
    tester.view.physicalSize =
        const Size(360, 800) * tester.view.devicePixelRatio;
    await tester.pumpAndSettle();

    await _tap(tester, _chip);

    expect(tester.takeException(), isNull);
    expect(find.text('3 en emisión'), findsOneWidget);
  });
}
