import '../support/list_equality.dart';
import '../values/anime_season.dart';
import '../values/broadcast.dart';

/// Read-only anime metadata from the catalog.
///
/// Search results only fill the basic fields. [description], [genres] and
/// [studioName] come from the detail lookup, and [broadcast] and
/// [memberCount] from the airing list, and MyAnimeList may still leave them
/// empty.
class CatalogAnime {
  const CatalogAnime({
    required this.malId,
    required this.title,
    this.coverUrl,
    this.totalEpisodes,
    this.seasonYear,
    this.season,
    this.isAiring = false,
    this.description,
    this.genres = const <String>[],
    this.studioName,
    this.broadcast,
    this.memberCount,
  });

  final int malId;
  final String title;
  final String? coverUrl;

  /// Null while airing or when unknown.
  final int? totalEpisodes;
  final int? seasonYear;

  /// Only meaningful together with [seasonYear].
  final AnimeSeason? season;

  final bool isAiring;

  /// Synopsis as plain text.
  final String? description;

  final List<String> genres;

  /// Name of the main studio only.
  final String? studioName;

  /// Null when the anime has no fixed weekly slot.
  final Broadcast? broadcast;

  /// How many MyAnimeList users have it in their list, as a measure of how
  /// well known it is; never shown, since the app has no statistics.
  final int? memberCount;

  @override
  bool operator ==(Object other) =>
      other is CatalogAnime &&
      other.malId == malId &&
      other.title == title &&
      other.coverUrl == coverUrl &&
      other.totalEpisodes == totalEpisodes &&
      other.seasonYear == seasonYear &&
      other.season == season &&
      other.isAiring == isAiring &&
      other.description == description &&
      sameElements(other.genres, genres) &&
      other.studioName == studioName &&
      other.broadcast == broadcast &&
      other.memberCount == memberCount;

  @override
  int get hashCode => Object.hash(
    malId,
    title,
    coverUrl,
    totalEpisodes,
    seasonYear,
    season,
    isAiring,
    description,
    Object.hashAll(genres),
    studioName,
    broadcast,
    memberCount,
  );

  @override
  String toString() => 'CatalogAnime($malId, $title)';
}
