import '../../domain/entities/catalog_anime.dart';
import '../../domain/values/broadcast.dart';
import '../../domain/values/release_date.dart';

/// Slack after the computed last episode for breaks and recap weeks, which
/// push the real one later.
const Duration _breakAllowance = Duration(days: 14);

/// Returns whether an anime has ended by its own numbers, whatever its
/// status says.
///
/// MyAnimeList can keep a finished series as airing for weeks, so a series
/// whose last episode, counted weekly from its start day, aired more than
/// two weeks ago is taken as ended. Without an episode count or a
/// full start date there is nothing to count, and the series still airs.
bool hasEnded(CatalogAnime anime, {required DateTime now}) {
  final int? episodes = anime.totalEpisodes;
  final ReleaseDate? start = anime.startDate;
  final (int? y, int? m, int? d) = (start?.year, start?.month, start?.day);
  if (episodes == null || y == null || m == null || d == null) return false;
  // Midnight in Japan after the day of the last episode, written as UTC so
  // that date arithmetic ignores the device time zone.
  final DateTime afterLastDay = DateTime.utc(
    y,
    m,
    d + (episodes - 1) * DateTime.daysPerWeek + 1,
  ).subtract(Broadcast.jstOffset);
  return !now.toUtc().isBefore(afterLastDay.add(_breakAllowance));
}
