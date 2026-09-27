import '../../domain/entities/catalog_anime.dart';
import '../../domain/values/anime_season.dart';
import '../../l10n/l10n.dart';

/// Returns the episode count, an airing label when the total is still
/// unknown, or null when there is nothing to show.
String? formatEpisodes(AppLocalizations l10n, CatalogAnime anime) {
  final int? total = anime.totalEpisodes;
  if (total != null) return l10n.metaEpisodes(total);
  return anime.isAiring ? l10n.metaAiring : null;
}

/// Returns the season and year, just the year when the season is unknown, or
/// null without a year.
String? formatSeason(AppLocalizations l10n, CatalogAnime anime) {
  final int? year = anime.seasonYear;
  if (year == null) return null;
  return formatSeasonOf(l10n, anime.season, year);
}

/// Returns [season] and [year], or just the year without a season.
String formatSeasonOf(AppLocalizations l10n, AnimeSeason? season, int year) {
  final String? label = _seasonLabel(l10n, season);
  return label == null ? '$year' : '$label $year';
}

String? _seasonLabel(AppLocalizations l10n, AnimeSeason? season) {
  switch (season) {
    case AnimeSeason.winter:
      return l10n.metaWinter;
    case AnimeSeason.spring:
      return l10n.metaSpring;
    case AnimeSeason.summer:
      return l10n.metaSummer;
    case AnimeSeason.fall:
      return l10n.metaFall;
    case null:
      return null;
  }
}
