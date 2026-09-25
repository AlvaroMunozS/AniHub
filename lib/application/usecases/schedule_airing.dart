import '../../domain/entities/catalog_anime.dart';
import '../../domain/values/broadcast.dart';
import 'title_key.dart';

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
  const AiringSchedule({required this.byWeekday, required this.unscheduled});

  /// Keyed by [DateTime.monday] to [DateTime.sunday]; a day without anime has
  /// no key.
  final Map<int, List<ScheduledAnime>> byWeekday;

  /// Anime without a fixed weekly slot, such as series released all at once.
  final List<CatalogAnime> unscheduled;

  int get length =>
      unscheduled.length +
      byWeekday.values.fold(0, (int sum, List<ScheduledAnime> day) {
        return sum + day.length;
      });
}

/// Sorts airing anime into the local weekdays they air on.
///
/// Broadcasts are in Japan Standard Time, so a late-night Japanese slot can
/// fall on the previous day elsewhere. Each one is converted at its
/// occurrence in the week of `now`, so the offset in force that week,
/// daylight saving time included, is the one used.
class ScheduleAiring {
  const ScheduleAiring({this.localOffset = _deviceOffset});

  /// Returns the local UTC offset at an instant; the device time zone unless
  /// a test fixes one.
  final Duration Function(DateTime utc) localOffset;

  static Duration _deviceOffset(DateTime utc) => utc.toLocal().timeZoneOffset;

  static const Duration _jstOffset = Duration(hours: 9);

  /// Returns [anime] by local weekday, each day ordered by time and title.
  /// Anime with a day but no time go last in their day, which stays the one
  /// in Japan since the time cannot be converted.
  AiringSchedule call(List<CatalogAnime> anime, {required DateTime now}) {
    final Map<int, List<ScheduledAnime>> byWeekday =
        <int, List<ScheduledAnime>>{};
    final List<CatalogAnime> unscheduled = <CatalogAnime>[];
    for (final CatalogAnime item in anime) {
      final Broadcast? broadcast = item.broadcast;
      if (broadcast == null) {
        unscheduled.add(item);
        continue;
      }
      final (int weekday, ScheduledAnime scheduled) = _toLocal(
        item,
        broadcast,
        now.toUtc(),
      );
      (byWeekday[weekday] ??= <ScheduledAnime>[]).add(scheduled);
    }
    for (final List<ScheduledAnime> day in byWeekday.values) {
      day.sort(_compareScheduled);
    }
    unscheduled.sort(_compareTitles);
    return AiringSchedule(
      byWeekday: <int, List<ScheduledAnime>>{
        for (final MapEntry<int, List<ScheduledAnime>> day in byWeekday.entries)
          day.key: List<ScheduledAnime>.unmodifiable(day.value),
      },
      unscheduled: List<CatalogAnime>.unmodifiable(unscheduled),
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
    final DateTime slotJst = DateTime.utc(
      nowJst.year,
      nowJst.month,
      nowJst.day + daysAhead,
      hour,
      minute,
    );
    final DateTime slotUtc = slotJst.subtract(_jstOffset);
    final DateTime local = slotUtc.add(localOffset(slotUtc));
    return (
      local.weekday,
      ScheduledAnime(anime, hour: local.hour, minute: local.minute),
    );
  }
}

int _compareScheduled(ScheduledAnime a, ScheduledAnime b) {
  final int? minutesA = a.hour == null ? null : a.hour! * 60 + a.minute!;
  final int? minutesB = b.hour == null ? null : b.hour! * 60 + b.minute!;
  if (minutesA != minutesB) {
    if (minutesA == null) return 1;
    if (minutesB == null) return -1;
    return minutesA.compareTo(minutesB);
  }
  return _compareTitles(a.anime, b.anime);
}

int _compareTitles(CatalogAnime a, CatalogAnime b) {
  final int keyCompare = titleKey(a.title).compareTo(titleKey(b.title));
  if (keyCompare != 0) return keyCompare;
  return a.malId.compareTo(b.malId);
}
