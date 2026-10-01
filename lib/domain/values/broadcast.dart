/// Weekly broadcast slot of an anime in Japan Standard Time (UTC+9, without
/// daylight saving time), which is how MyAnimeList gives it.
class Broadcast {
  const Broadcast({required this.weekday, this.hour, this.minute})
    : assert(weekday >= DateTime.monday && weekday <= DateTime.sunday),
      assert((hour == null) == (minute == null));

  /// Japan Standard Time, which has no daylight saving time, so a slot is
  /// always this far ahead of UTC.
  static const Duration jstOffset = Duration(hours: 9);

  /// From [DateTime.monday] to [DateTime.sunday].
  final int weekday;

  /// Null, like [minute], when only the day is known.
  final int? hour;
  final int? minute;

  @override
  bool operator ==(Object other) =>
      other is Broadcast &&
      other.weekday == weekday &&
      other.hour == hour &&
      other.minute == minute;

  @override
  int get hashCode => Object.hash(weekday, hour, minute);

  @override
  String toString() => 'Broadcast($weekday, $hour:$minute)';

  /// Returns the UTC instant of the first broadcast strictly after [instant],
  /// or null when only the day is known.
  DateTime? nextAfter(DateTime instant) {
    final int? hour = this.hour;
    final int? minute = this.minute;
    if (hour == null || minute == null) return null;
    // Japan's clock, written as UTC so that date arithmetic ignores the
    // device time zone.
    final DateTime nowJst = instant.toUtc().add(jstOffset);
    final int daysAhead = (weekday - nowJst.weekday) % DateTime.daysPerWeek;
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
    return slotJst.subtract(jstOffset);
  }
}
