import '../../domain/entities/catalog_anime.dart';
import '../../domain/values/airing_reminder.dart';
import '../../domain/values/broadcast.dart';
import '../../domain/values/release_date.dart';

/// Turns the airing list into reminders of the series being watched.
///
/// Only [horizon] ahead is planned: the app plans again whenever it is
/// opened, and a series that ends or moves its slot leaves the airing list,
/// so its reminders stop without asking MyAnimeList in the background.
/// The popularity threshold of `ScheduleAiring` does not apply: these are the
/// user's own series.
class PlanAiringReminders {
  const PlanAiringReminders();

  static const Duration horizon = Duration(days: 14);

  List<AiringReminder> call(
    List<CatalogAnime> airing, {
    required Set<int> watching,
    required DateTime now,
  }) {
    final DateTime start = now.toUtc();
    final DateTime end = start.add(horizon);
    final List<AiringReminder> reminders = <AiringReminder>[];
    for (final CatalogAnime anime in airing) {
      final Broadcast? broadcast = anime.broadcast;
      if (!watching.contains(anime.malId) || broadcast == null) continue;
      final DateTime? premiere = _premiere(anime);
      if (!anime.isAiring && premiere == null) continue;
      for (
        DateTime? at = broadcast.nextAfter(start);
        at != null && !at.isAfter(end);
        at = broadcast.nextAfter(at)
      ) {
        if (premiere != null && at.isBefore(premiere)) continue;
        reminders.add(
          AiringReminder(malId: anime.malId, title: anime.title, at: at),
        );
      }
    }
    return reminders..sort((AiringReminder a, AiringReminder b) {
      final int byTime = a.at.compareTo(b.at);
      return byTime != 0 ? byTime : a.malId.compareTo(b.malId);
    });
  }

  /// Midnight in Japan on the premiere day, when MyAnimeList knows the day.
  static DateTime? _premiere(CatalogAnime anime) {
    if (anime.isAiring) return null;
    final ReleaseDate? date = anime.startDate;
    final (int? y, int? m, int? d) = (date?.year, date?.month, date?.day);
    if (y == null || m == null || d == null) return null;
    return DateTime.utc(y, m, d).subtract(Broadcast.jstOffset);
  }
}
