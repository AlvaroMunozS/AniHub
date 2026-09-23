import 'package:anihub/domain/entities/catalog_anime.dart';
import 'package:anihub/domain/values/anime_season.dart';
import 'package:anihub/ui/format/anime_meta.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatEpisodes', () {
    test('uses the singular for one episode', () {
      const CatalogAnime anime = CatalogAnime(
        malId: 1,
        title: 'x',
        totalEpisodes: 1,
      );
      expect(formatEpisodes(anime), '1 episodio');
    });

    test('uses the plural for several episodes', () {
      const CatalogAnime anime = CatalogAnime(
        malId: 1,
        title: 'x',
        totalEpisodes: 12,
      );
      expect(formatEpisodes(anime), '12 episodios');
    });

    test('labels an airing anime without a total', () {
      const CatalogAnime anime = CatalogAnime(
        malId: 1,
        title: 'x',
        isAiring: true,
      );
      expect(formatEpisodes(anime), 'En emisión');
    });

    test('returns null without a total when not airing', () {
      const CatalogAnime anime = CatalogAnime(malId: 1, title: 'x');
      expect(formatEpisodes(anime), isNull);
    });
  });

  group('formatSeason', () {
    test('formats every season with its year', () {
      const List<(AnimeSeason, String)> cases = <(AnimeSeason, String)>[
        (AnimeSeason.winter, 'Invierno'),
        (AnimeSeason.spring, 'Primavera'),
        (AnimeSeason.summer, 'Verano'),
        (AnimeSeason.fall, 'Otoño'),
      ];
      for (final (AnimeSeason season, String label) in cases) {
        final CatalogAnime anime = CatalogAnime(
          malId: 1,
          title: 'x',
          seasonYear: 2026,
          season: season,
        );
        expect(formatSeason(anime), '$label 2026');
      }
    });

    test('returns only the year without a season', () {
      const CatalogAnime anime = CatalogAnime(
        malId: 1,
        title: 'x',
        seasonYear: 2009,
      );
      expect(formatSeason(anime), '2009');
    });

    test('returns null without a year', () {
      const CatalogAnime anime = CatalogAnime(malId: 1, title: 'x');
      expect(formatSeason(anime), isNull);
    });
  });
}
