import 'package:anihub/application/usecases/usecases.dart';
import 'package:anihub/domain/entities/catalog_anime.dart';
import 'package:anihub/domain/entities/entry.dart';
import 'package:anihub/domain/values/broadcast.dart';
import 'package:anihub/domain/values/watch_status.dart';
import 'package:anihub/ui/providers.dart';
import 'package:anihub/ui/router.dart';
import 'package:anihub/ui/screens/anime_detail_screen.dart';
import 'package:anihub/ui/theme/app_theme.dart';
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

/// Twenty popular series on Thursday, more than a phone shows at once.
final List<CatalogAnime> _longThursday = <CatalogAnime>[
  for (int i = 0; i < 20; i++)
    CatalogAnime(
      malId: 400 + i,
      title: 'Series $i',
      broadcast: _thursday(21),
      memberCount: 900000 - i,
    ),
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

/// The bookmark in the search bar that shows only the series being watched.
Finder get _mine => find.byTooltip(spanish.searchAiringMine);

bool _mineSelected(WidgetTester tester) => tester
    .widget<IconButton>(
      find.ancestor(of: _mine, matching: find.byType(IconButton)),
    )
    .isSelected!;

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Color? _dayColor(WidgetTester tester, String day) =>
    tester.widget<Text>(find.text(day)).style?.color;

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

    await _tap(tester, _mine);

    expect(_titles(tester), <String>['Early mine', 'Niche mine', 'Late mine']);
    expect(_cards(tester).any((CatalogCard c) => c.inLibrary), isFalse);
    expect(_mineSelected(tester), isTrue);
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
    expect(_titles(tester), <String>[
      'Popular other',
      'Late mine',
      'Early mine',
      'Niche mine',
    ]);
  });

  testWidgets('says when none of your series airs on a day', (
    WidgetTester tester,
  ) async {
    await _pumpBrowse(tester);
    await _tap(tester, _mine);

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
    await _tap(tester, _mine);

    expect(find.text(spanish.searchAiringMineEmptyTitle), findsOneWidget);
    await _tap(tester, find.text(spanish.searchAiringMineShowAll));

    expect(find.widgetWithText(CatalogCard, 'Popular other'), findsOneWidget);
    expect(_mineSelected(tester), isFalse);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('browse.airing.onlyMine'), isFalse);
  });

  testWidgets(
    'hides the bookmark in other seasons and keeps the filter for the '
    'current one',
    (WidgetTester tester) async {
      await _pumpBrowse(
        tester,
        premieres: <CatalogAnime>[
          const CatalogAnime(
            malId: 301,
            title: 'Late mine',
            memberCount: 900000,
          ),
          const CatalogAnime(
            malId: 307,
            title: 'Past hit',
            memberCount: 800000,
          ),
        ],
      );
      final double fieldWidthInCurrentSeason = tester
          .getSize(find.byType(TextField))
          .width;
      await _tap(tester, _mine);

      await _tap(tester, find.byTooltip(spanish.searchSeasonPrevious));

      expect(_mine, findsNothing);
      expect(
        tester.getSize(find.byType(TextField)).width,
        fieldWidthInCurrentSeason,
      );
      expect(find.widgetWithText(CatalogCard, 'Past hit'), findsOneWidget);
      final CatalogCard mine = tester.widget<CatalogCard>(
        find.widgetWithText(CatalogCard, 'Late mine'),
      );
      expect(mine.inLibrary, isTrue);

      await _tap(tester, find.byTooltip(spanish.searchSeasonNext));

      expect(_mineSelected(tester), isTrue);
      expect(_titles(tester), <String>[
        'Early mine',
        'Niche mine',
        'Late mine',
      ]);
    },
  );

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
    await _tap(tester, _mine);

    final Entry late = (await repo.findAll()).firstWhere(
      (Entry e) => e.malId == 301,
    );
    await repo.save(late.withStatus(WatchStatus.completed));
    await tester.pumpAndSettle();

    expect(_titles(tester), <String>['Early mine', 'Niche mine']);
  });

  testWidgets('hides the bookmark when nothing airs this season', (
    WidgetTester tester,
  ) async {
    await _pumpBrowse(
      tester,
      airing: const <CatalogAnime>[],
      prefs: <String, Object>{'browse.airing.onlyMine': true},
    );

    expect(_mine, findsNothing);
    expect(find.text(spanish.searchAiringEmptyTitle), findsOneWidget);
  });

  testWidgets('fits the stepper and the bookmark with large text', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pumpBrowse(tester);
    tester.view.physicalSize =
        const Size(360, 800) * tester.view.devicePixelRatio;
    await tester.pumpAndSettle();

    await _tap(tester, _mine);

    expect(tester.takeException(), isNull);
    expect(find.byTooltip(spanish.searchSeasonPrevious), findsOneWidget);
    expect(_mine, findsOneWidget);
  });

  testWidgets('hides the bookmark while typing and shows it again when '
      'cleared', (WidgetTester tester) async {
    await _pumpBrowse(tester);

    await tester.enterText(find.byType(TextField), 'f');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(_mine, findsNothing);

    await _tap(tester, find.byTooltip(spanish.searchBarClear));

    expect(_mine, findsOneWidget);
  });

  testWidgets('lets the last row scroll above the season arrows', (
    WidgetTester tester,
  ) async {
    await _pumpBrowse(tester, airing: _longThursday);

    await tester.fling(
      find.byType(CatalogCard).first,
      const Offset(0, -5000),
      3000,
    );
    await tester.pumpAndSettle();

    final Rect last = tester.getRect(
      find.widgetWithText(CatalogCard, 'Series 19'),
    );
    expect(
      last.bottom,
      lessThanOrEqualTo(
        tester.getRect(find.byTooltip(spanish.searchSeasonPrevious)).top,
      ),
    );
  });

  testWidgets('opens a poster under the fade beside the arrows', (
    WidgetTester tester,
  ) async {
    await _pumpBrowse(tester, airing: _longThursday);
    final Rect previous = tester.getRect(
      find.byTooltip(spanish.searchSeasonPrevious),
    );

    await tester.tapAt(Offset(AppSpacing.s24, previous.center.dy));
    await tester.pumpAndSettle();

    expect(
      tester.widget<AnimeDetailScreen>(find.byType(AnimeDetailScreen)).malId,
      406,
    );
  });

  testWidgets('dims the days none of your series airs', (
    WidgetTester tester,
  ) async {
    await _pumpBrowse(tester);
    final Color faint = tester.element(find.text('vie')).palette.textFaint;
    final Offset arrow = tester.getCenter(
      find.byTooltip(spanish.searchSeasonPrevious),
    );

    expect(_dayColor(tester, 'vie'), isNot(faint));

    await _tap(tester, _mine);

    expect(_dayColor(tester, 'vie'), faint);
    expect(_dayColor(tester, 'jue'), isNot(faint));
    expect(
      tester.getCenter(find.byTooltip(spanish.searchSeasonPrevious)),
      arrow,
    );
  });
}
