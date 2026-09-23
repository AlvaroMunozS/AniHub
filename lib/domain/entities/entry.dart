import '../values/watch_status.dart';

/// An anime in the user's library.
class Entry {
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
       );

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

  Entry copyWith({
    String? id,
    int? malId,
    String? title,
    String? coverUrl,
    int? totalEpisodes,
    WatchStatus? status,
    DateTime? updatedAt,
    bool? isFavorite,
  }) {
    return Entry(
      id: id ?? this.id,
      malId: malId ?? this.malId,
      title: title ?? this.title,
      coverUrl: coverUrl ?? this.coverUrl,
      totalEpisodes: totalEpisodes ?? this.totalEpisodes,
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
      isFavorite: isFavorite ?? this.isFavorite,
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
