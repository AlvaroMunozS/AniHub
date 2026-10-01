import '../../domain/entities/catalog_anime.dart';
import '../../domain/values/broadcast.dart';
import 'relevance.dart';

/// An anime of an [AiringSchedule] with its broadcast time in local time.
class ScheduledAnime {
  const ScheduledAnime(this.anime, {this.hour, this.minute});

  final CatalogAnime anime;

  /// Null, like [minute], when only the broadcast day is known.
  final int? hour;
  final int? minute;
}

/// Airing anime by local weekday.
class AiringSchedule {
  const AiringSchedule({required this.byWeekday});

  /// Keyed by [DateTime.monday] to [DateTime.sunday]; a day without anime has
  /// no key.
  final Map<int, List<ScheduledAnime>> byWeekday;

  /// How many anime the schedule lists.
  int get length =>
      byWeekday.values.fold(0, (int sum, List<ScheduledAnime> day) {
        return sum + day.length;
      });

  bool get isEmpty => length == 0;
}

/// Sorts the better known airing anime into the local weekdays they air on.
///
/// Anime in fewer than [minMembers] MyAnimeList lists are left out: most
/// airing series are short web series or children's shows that few people
/// follow, and they would bury the ones worth finding. Anime without a
/// weekly slot are left out too, since they have no day to go under; most are
/// Chinese series MyAnimeList has no schedule for, or series released all at
/// once.
///
/// Broadcasts are in Japan Standard Time, so a late-night Japanese slot can
/// fall on the previous day elsewhere. Each one is converted at its next
/// occurrence after `now`, so the offset in force then, daylight saving time
/// included, is the one used. A slot that has already aired today counts as
/// next week's.
class ScheduleAiring {
  const ScheduleAiring({this.localOffset = _deviceOffset});

  /// Returns the local UTC offset at an instant; the device time zone unless
  /// a test fixes one.
  final Duration Function(DateTime utc) localOffset;

  static Duration _deviceOffset(DateTime utc) => utc.toLocal().timeZoneOffset;

  static const Duration _jstOffset = Duration(hours: 9);

  /// Fewest MyAnimeList lists an anime must be in to be listed. Anime whose
  /// count is unknown are listed.
  static const int minMembers = 5000;

  /// Returns [anime] by local weekday, most followed first. An anime with a
  /// day but no time stays on its day in Japan, since the time cannot be
  /// converted.
  AiringSchedule call(List<CatalogAnime> anime, {required DateTime now}) {
    final Map<int, List<ScheduledAnime>> byWeekday =
        <int, List<ScheduledAnime>>{};
    for (final CatalogAnime item in anime) {
      if ((item.memberCount ?? minMembers) < minMembers) continue;
      final Broadcast? broadcast = item.broadcast;
      if (broadcast == null) continue;
      final (int weekday, ScheduledAnime scheduled) = _toLocal(
        item,
        broadcast,
        now.toUtc(),
      );
      (byWeekday[weekday] ??= <ScheduledAnime>[]).add(scheduled);
    }
    for (final List<ScheduledAnime> day in byWeekday.values) {
      day.sort(
        (ScheduledAnime a, ScheduledAnime b) =>
            compareRelevance(a.anime, b.anime),
      );
    }
    return AiringSchedule(
      byWeekday: <int, List<ScheduledAnime>>{
        for (final MapEntry<int, List<ScheduledAnime>> day in byWeekday.entries)
          day.key: List<ScheduledAnime>.unmodifiable(day.value),
      },
    );
  }

  (int, ScheduledAnime) _toLocal(
    CatalogAnime anime,
    Broadcast broadcast,
    DateTime nowUtc,
  ) {
    final int? hour = broadcast.hour;
    final int? minute = broadcast.minute;
    if (hour == null || minute == null) {
      return (broadcast.weekday, ScheduledAnime(anime));
    }
    // Japan's clock, written as UTC so that date arithmetic ignores the
    // device time zone.
    final DateTime nowJst = nowUtc.add(_jstOffset);
    final int daysAhead = (broadcast.weekday - nowJst.weekday) % 7;
    DateTime slotJst = DateTime.utc(
      nowJst.year,
      nowJst.month,
      nowJst.day + daysAhead,
      hour,
      minute,
    );
    if (!slotJst.isAfter(nowJst)) {
      slotJst = DateTime.utc(
        slotJst.year,
        slotJst.month,
        slotJst.day + DateTime.daysPerWeek,
        hour,
        minute,
      );
    }
    final DateTime slotUtc = slotJst.subtract(_jstOffset);
    final DateTime local = slotUtc.add(localOffset(slotUtc));
    return (
      local.weekday,
      ScheduledAnime(anime, hour: local.hour, minute: local.minute),
    );
  }
}
