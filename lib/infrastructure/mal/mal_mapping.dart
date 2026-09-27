import '../../domain/errors/catalog_exception.dart';
import '../../domain/values/anime_season.dart';
import '../../domain/values/broadcast.dart';
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

/// Parses `broadcast`, whose `start_time` is `HH:mm` in Japan Standard Time.
///
/// Returns null when there is no weekday, as with `other`, and a
/// [Broadcast] without a time when `start_time` is missing or unreadable.
Broadcast? parseBroadcast(Map<String, Object?> node) {
  final int? weekday = switch (node) {
    {'broadcast': {'day_of_the_week': final String day}} => _weekdays[day],
    _ => null,
  };
  if (weekday == null) return null;
  final List<int?> time = switch (node) {
    {'broadcast': {'start_time': final String raw}} =>
      raw.split(':').map(int.tryParse).toList(),
    _ => const <int?>[],
  };
  if (time case [final int hour, final int minute]
      when hour >= 0 && hour < 24 && minute >= 0 && minute < 60) {
    return Broadcast(weekday: weekday, hour: hour, minute: minute);
  }
  return Broadcast(weekday: weekday);
}

const Map<String, int> _weekdays = <String, int>{
  'monday': DateTime.monday,
  'tuesday': DateTime.tuesday,
  'wednesday': DateTime.wednesday,
  'thursday': DateTime.thursday,
  'friday': DateTime.friday,
  'saturday': DateTime.saturday,
  'sunday': DateTime.sunday,
};
