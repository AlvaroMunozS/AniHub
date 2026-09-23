/// A possibly partial release date.
///
/// It may carry only the year, the year and month, or all three fields.
class ReleaseDate {
  const ReleaseDate({this.year, this.month, this.day});

  final int? year;
  final int? month;
  final int? day;

  /// A key that orders dates chronologically, or null when [year] is unknown.
  ///
  /// A missing month or day counts as zero, so a less precise date sorts
  /// before a more precise one in the same year instead of tying with it.
  int? get sortKey =>
      year == null ? null : year! * 10000 + (month ?? 0) * 100 + (day ?? 0);

  @override
  bool operator ==(Object other) =>
      other is ReleaseDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => 'ReleaseDate($year-$month-$day)';
}
