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

  /// Returns a schedule with only the anime in [malIds], each day by local
  /// broadcast time, the ones without a time last.
  ///
  /// Read as a timetable of the user's own series, so the order is the
  /// clock's; anime at the same time keep the most followed first.
  AiringSchedule only(Set<int> malIds) {
    final Map<int, List<ScheduledAnime>> kept = <int, List<ScheduledAnime>>{};
    for (final MapEntry<int, List<ScheduledAnime>> day in byWeekday.entries) {
      final List<ScheduledAnime> mine = <ScheduledAnime>[
        for (final ScheduledAnime item in day.value)
          if (malIds.contains(item.anime.malId)) item,
      ]..sort(_byTime);
      if (mine.isNotEmpty) {
        kept[day.key] = List<ScheduledAnime>.unmodifiable(mine);
      }
    }
    return AiringSchedule(byWeekday: kept);
  }

  static int _byTime(ScheduledAnime a, ScheduledAnime b) {
    final int? aMinutes = _minuteOfDay(a);
    final int? bMinutes = _minuteOfDay(b);
    if (aMinutes != bMinutes) {
      if (aMinutes == null) return 1;
      if (bMinutes == null) return -1;
      return aMinutes.compareTo(bMinutes);
    }
    return compareRelevance(a.anime, b.anime);
  }

  static int? _minuteOfDay(ScheduledAnime item) {
    final int? hour = item.hour;
    final int? minute = item.minute;
    if (hour == null || minute == null) return null;
    return hour * Duration.minutesPerHour + minute;
  }
}

/// Sorts the better known airing anime into the local weekdays they air on.
///
/// Anime in fewer than [minMembers] MyAnimeList lists are left out: most
/// airing series are short web series or children's shows that few people
/// follow, and they would bury the ones worth finding. The threshold is there
/// to find new series, not to hide the user's own, so the caller can name
/// anime that are always kept. Anime without a weekly slot are left out too,
/// since they have no day to go under; most are Chinese series MyAnimeList
/// has no schedule for, or series released all at once.
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

  /// Fewest MyAnimeList lists an anime must be in to be listed. Anime whose
  /// count is unknown are listed.
  static const int minMembers = 5000;

  /// Returns [anime] by local weekday, most followed first. An anime with a
  /// day but no time stays on its day in Japan, since the time cannot be
  /// converted. The anime in [keep] are listed however few lists hold them.
  AiringSchedule call(
    List<CatalogAnime> anime, {
    required DateTime now,
    Set<int> keep = const <int>{},
  }) {
    final Map<int, List<ScheduledAnime>> byWeekday =
        <int, List<ScheduledAnime>>{};
    for (final CatalogAnime item in anime) {
      if (!keep.contains(item.malId) &&
          (item.memberCount ?? minMembers) < minMembers) {
        continue;
      }
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
    final DateTime? slotUtc = broadcast.nextAfter(nowUtc);
    if (slotUtc == null) {
      return (broadcast.weekday, ScheduledAnime(anime));
    }
    final DateTime local = slotUtc.add(localOffset(slotUtc));
    return (
      local.weekday,
      ScheduledAnime(anime, hour: local.hour, minute: local.minute),
    );
  }
}
