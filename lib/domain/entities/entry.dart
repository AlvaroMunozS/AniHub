import '../values/watch_status.dart';

/// An anime in the user's library.
///
/// Only a [WatchStatus.completed] entry can be a favorite. The constructor
/// enforces it, and [withStatus] and [withFavorite] move between valid
/// states.
class Entry {
  /// Throws an [ArgumentError] if [isFavorite] is set on an entry that is not
  /// [WatchStatus.completed].
  Entry({
    required this.malId,
    required this.title,
    required this.status,
    required this.updatedAt,
    this.id,
    this.coverUrl,
    this.totalEpisodes,
    this.isFavorite = false,
  }) : assert(
         totalEpisodes == null || totalEpisodes >= 0,
         'totalEpisodes must not be negative',
       ) {
    // Not an assert: release builds must never store this combination.
    if (isFavorite && status != WatchStatus.completed) {
      throw ArgumentError.value(
        isFavorite,
        'isFavorite',
        'Only a completed entry can be a favorite, not a ${status.wire} one',
      );
    }
  }

  /// Assigned by the repository; null until the entry is persisted.
  final String? id;
  final int malId;
  final String title;
  final String? coverUrl;

  /// Null while airing or when unknown.
  ///
  /// Catalog metadata only: watched episodes are not tracked.
  final int? totalEpisodes;
  final WatchStatus status;
  final DateTime updatedAt;
  final bool isFavorite;

  /// Returns a copy with the given fields replaced.
  ///
  /// The status and the favorite flag change only through [withStatus] and
  /// [withFavorite], which keep them consistent.
  Entry copyWith({
    String? id,
    int? malId,
    String? title,
    String? coverUrl,
    int? totalEpisodes,
    DateTime? updatedAt,
  }) {
    return Entry(
      id: id ?? this.id,
      malId: malId ?? this.malId,
      title: title ?? this.title,
      coverUrl: coverUrl ?? this.coverUrl,
      totalEpisodes: totalEpisodes ?? this.totalEpisodes,
      status: status,
      updatedAt: updatedAt ?? this.updatedAt,
      isFavorite: isFavorite,
    );
  }

  /// Returns a copy with [status], keeping the favorite only if [status] is
  /// [WatchStatus.completed].
  Entry withStatus(WatchStatus status) => _with(
    status: status,
    isFavorite: isFavorite && status == WatchStatus.completed,
  );

  /// Returns a copy with [isFavorite], completing the entry when it becomes
  /// a favorite.
  Entry withFavorite(bool isFavorite) => _with(
    status: isFavorite ? WatchStatus.completed : status,
    isFavorite: isFavorite,
  );

  Entry _with({required WatchStatus status, required bool isFavorite}) {
    return Entry(
      id: id,
      malId: malId,
      title: title,
      coverUrl: coverUrl,
      totalEpisodes: totalEpisodes,
      status: status,
      updatedAt: updatedAt,
      isFavorite: isFavorite,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Entry &&
      other.id == id &&
      other.malId == malId &&
      other.title == title &&
      other.coverUrl == coverUrl &&
      other.totalEpisodes == totalEpisodes &&
      other.status == status &&
      other.updatedAt == updatedAt &&
      other.isFavorite == isFavorite;

  @override
  int get hashCode => Object.hash(
    id,
    malId,
    title,
    coverUrl,
    totalEpisodes,
    status,
    updatedAt,
    isFavorite,
  );

  @override
  String toString() =>
      'Entry($title, ${status.wire}, ${totalEpisodes ?? '?'} ep)';
}
