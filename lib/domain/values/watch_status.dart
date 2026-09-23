/// Watch status of a library entry.
///
/// Deliberately limited to these three states.
enum WatchStatus {
  watching('watching'),
  planned('planned'),
  completed('completed');

  const WatchStatus(this.wire);

  /// Value stored in the database and in library backups.
  final String wire;

  /// Parses a stored [wire] value.
  ///
  /// Throws an [ArgumentError] if [value] is unknown.
  static WatchStatus fromWire(String value) =>
      tryFromWire(value) ??
      (throw ArgumentError.value(value, 'value', 'Unknown watch status'));

  /// Parses a [wire] value, or returns null if it is unknown.
  static WatchStatus? tryFromWire(String value) {
    for (final status in WatchStatus.values) {
      if (status.wire == value) return status;
    }
    return null;
  }
}
