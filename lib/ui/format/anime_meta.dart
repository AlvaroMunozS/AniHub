import '../../domain/entities/catalog_anime.dart';
import '../../domain/values/anime_season.dart';

/// Returns the episode count, an airing label when the total is still
/// unknown, or null when there is nothing to show.
String? formatEpisodes(CatalogAnime anime) {
  final int? total = anime.totalEpisodes;
  if (total != null) {
    return total == 1 ? '1 episodio' : '$total episodios';
  }
  return anime.isAiring ? 'En emisión' : null;
}

/// Returns the season and year, just the year when the season is unknown, or
/// null without a year.
String? formatSeason(CatalogAnime anime) {
  final int? year = anime.seasonYear;
  if (year == null) return null;
  final String? label = _seasonLabel(anime.season);
  return label == null ? '$year' : '$label $year';
}

String? _seasonLabel(AnimeSeason? season) {
  switch (season) {
    case AnimeSeason.winter:
      return 'Invierno';
    case AnimeSeason.spring:
      return 'Primavera';
    case AnimeSeason.summer:
      return 'Verano';
    case AnimeSeason.fall:
      return 'Otoño';
    case null:
      return null;
  }
}
