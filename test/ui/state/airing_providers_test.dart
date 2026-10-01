import 'package:anihub/domain/values/anime_season.dart';
import 'package:anihub/ui/providers.dart';
import 'package:anihub/ui/state/airing_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_anime_catalog.dart';

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
}
