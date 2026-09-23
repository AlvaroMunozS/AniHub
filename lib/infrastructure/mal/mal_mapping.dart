import '../../domain/errors/catalog_exception.dart';
import '../../domain/values/anime_season.dart';
import '../../domain/values/release_date.dart';

/// Returns the `id` of a MyAnimeList anime node.
///
/// Throws a [CatalogResponseException] if it is missing.
int parseId(Map<String, Object?> node) => switch (node) {
  {'id': final int id} => id,
  _ => throw const CatalogResponseException('Anime node without an id'),
};

/// Returns the English title when there is one, or the main title otherwise.
///
/// Returns null if neither is set.
String? parseTitle(Map<String, Object?> node) {
  if (node case {'alternative_titles': {'en': final String english}}
      when english.trim().isNotEmpty) {
    return english;
  }
  if (node case {'title': final String title} when title.trim().isNotEmpty) {
    return title;
  }
  return null;
}

/// Like [parseTitle], but throws a [CatalogResponseException] when [node] has
/// no title.
String requireTitle(Map<String, Object?> node) =>
    parseTitle(node) ??
    (throw CatalogResponseException('Anime ${node['id']} has no title'));

/// Returns the large cover, or the medium one when there is no large one.
String? parseCoverUrl(Map<String, Object?> node) => switch (node) {
  {'main_picture': {'large': final String url}} => url,
  {'main_picture': {'medium': final String url}} => url,
  _ => null,
};

AnimeSeason? parseSeason(Map<String, Object?> node) => switch (node) {
  {'start_season': {'season': 'winter'}} => AnimeSeason.winter,
  {'start_season': {'season': 'spring'}} => AnimeSeason.spring,
  {'start_season': {'season': 'summer'}} => AnimeSeason.summer,
  {'start_season': {'season': 'fall'}} => AnimeSeason.fall,
  _ => null,
};

/// Returns the year of `start_season`, or that of `start_date` when the
/// season is not set yet.
int? parseYear(Map<String, Object?> node) => switch (node) {
  {'start_season': {'year': final int year}} => year,
  _ => parseStartDate(node)?.year,
};

/// Parses `start_date`, which MyAnimeList gives as `YYYY`, `YYYY-MM` or
/// `YYYY-MM-DD`.
ReleaseDate? parseStartDate(Map<String, Object?> node) {
  if (node case {'start_date': final String raw}) {
    final List<int?> parts = raw.split('-').map(int.tryParse).toList();
    if (parts.length > 3 || parts.contains(null)) return null;
    return ReleaseDate(
      year: parts[0],
      month: parts.length > 1 ? parts[1] : null,
      day: parts.length > 2 ? parts[2] : null,
    );
  }
  return null;
}
