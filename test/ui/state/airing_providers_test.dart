import 'package:anihub/domain/entities/entry.dart';
import 'package:anihub/domain/values/anime_season.dart';
import 'package:anihub/domain/values/watch_status.dart';
import 'package:anihub/ui/providers.dart';
import 'package:anihub/ui/state/airing_providers.dart';
import 'package:anihub/ui/state/library_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_anime_catalog.dart';
import '../../support/in_memory_entry_repository.dart';

void main() {
  test('starts on the current season and goes one season forward at most', () {
    final ProviderContainer container = ProviderContainer.test();
    final BrowsedSeasonOffset offset = container.read(
      browsedSeasonOffsetProvider.notifier,
    );

    expect(container.read(browsedSeasonOffsetProvider), 0);
    offset
      ..next()
      ..next();
    expect(
      container.read(browsedSeasonOffsetProvider),
      BrowsedSeasonOffset.max,
    );
    offset
      ..previous()
      ..previous()
      ..previous();
    expect(container.read(browsedSeasonOffsetProvider), -2);
    offset.reset();
    expect(container.read(browsedSeasonOffsetProvider), 0);
  });

  test('requests the premieres of a season once', () async {
    final FakeAnimeCatalog catalog = FakeAnimeCatalog();
    final ProviderContainer container = ProviderContainer.test(
      overrides: [animeCatalogProvider.overrideWithValue(catalog)],
    );
    const YearSeason spring = (year: 2025, season: AnimeSeason.spring);

    await container.read(seasonPremieresProvider(spring).future);
    await container.read(seasonPremieresProvider(spring).future);

    expect(catalog.premiereRequests, <(int, AnimeSeason)>[
      (2025, AnimeSeason.spring),
    ]);
  });

  test('remembers whether only the series being watched are shown', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    ProviderContainer open() => ProviderContainer.test(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );

    final ProviderContainer first = open();
    expect(first.read(airingOnlyMineProvider), isFalse);
    first.read(airingOnlyMineProvider.notifier).set(true);

    expect(first.read(airingOnlyMineProvider), isTrue);
    expect(open().read(airingOnlyMineProvider), isTrue);
  });

  test('lists the series being watched and no others', () async {
    final InMemoryEntryRepository repo = InMemoryEntryRepository(
      seed: <Entry>[
        Entry(
          malId: 1,
          title: 'Watching',
          status: WatchStatus.watching,
          updatedAt: DateTime(2026, 9),
        ),
        Entry(
          malId: 2,
          title: 'Planned',
          status: WatchStatus.planned,
          updatedAt: DateTime(2026, 9),
        ),
      ],
    );
    addTearDown(repo.dispose);
    final ProviderContainer container = ProviderContainer.test(
      overrides: [entryRepositoryProvider.overrideWithValue(repo)],
    );

    // Riverpod pauses a stream nobody listens to, so it would never emit.
    container.listen(watchingIdsProvider, (_, _) {});

    expect(container.read(watchingIdsProvider), isEmpty);
    await container.read(libraryEntriesProvider.future);

    expect(container.read(watchingIdsProvider), <int>{1});
  });
}
