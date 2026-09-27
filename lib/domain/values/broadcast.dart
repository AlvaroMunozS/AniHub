/// Weekly broadcast slot of an anime in Japan Standard Time (UTC+9, without
/// daylight saving time), which is how MyAnimeList gives it.
class Broadcast {
  const Broadcast({required this.weekday, this.hour, this.minute})
    : assert(weekday >= DateTime.monday && weekday <= DateTime.sunday),
      assert((hour == null) == (minute == null));

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
}
