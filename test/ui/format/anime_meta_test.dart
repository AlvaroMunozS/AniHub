import 'package:anihub/domain/entities/catalog_anime.dart';
import 'package:anihub/domain/values/anime_season.dart';
import 'package:anihub/l10n/l10n.dart';
import 'package:anihub/ui/format/anime_meta.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final AppLocalizations es = lookupAppLocalizations(const Locale('es'));
  final AppLocalizations en = lookupAppLocalizations(const Locale('en'));

  group('formatEpisodes', () {
    test('uses the singular for one episode', () {
      const CatalogAnime anime = CatalogAnime(
        malId: 1,
        title: 'x',
        totalEpisodes: 1,
      );
      expect(formatEpisodes(es, anime), '1 episodio');
      expect(formatEpisodes(en, anime), '1 episode');
    });

    test('uses the plural for several episodes', () {
      const CatalogAnime anime = CatalogAnime(
        malId: 1,
        title: 'x',
        totalEpisodes: 12,
      );
      expect(formatEpisodes(es, anime), '12 episodios');
      expect(formatEpisodes(en, anime), '12 episodes');
    });

    test('labels an airing anime without a total', () {
      const CatalogAnime anime = CatalogAnime(
        malId: 1,
        title: 'x',
        isAiring: true,
      );
      expect(formatEpisodes(es, anime), 'En emisión');
      expect(formatEpisodes(en, anime), 'Airing');
    });

    test('returns null without a total when not airing', () {
      const CatalogAnime anime = CatalogAnime(malId: 1, title: 'x');
      expect(formatEpisodes(es, anime), isNull);
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
        expect(formatSeason(es, anime), '$label 2026');
      }
    });

    test('names the season in the given language', () {
      const CatalogAnime anime = CatalogAnime(
        malId: 1,
        title: 'x',
        seasonYear: 2026,
        season: AnimeSeason.fall,
      );
      expect(formatSeason(en, anime), 'Fall 2026');
    });

    test('returns only the year without a season', () {
      const CatalogAnime anime = CatalogAnime(
        malId: 1,
        title: 'x',
        seasonYear: 2009,
      );
      expect(formatSeason(es, anime), '2009');
    });

    test('returns null without a year', () {
      const CatalogAnime anime = CatalogAnime(malId: 1, title: 'x');
      expect(formatSeason(es, anime), isNull);
    });
  });
}
