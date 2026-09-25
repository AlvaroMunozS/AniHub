import '../entities/catalog_anime.dart';
import '../errors/catalog_exception.dart';
import '../values/anime_season.dart';

/// Read-only access to anime metadata.
abstract interface class AnimeCatalog {
  /// The shortest trimmed query that [search] looks up.
  int get minQueryLength;

  /// Returns up to [limit] anime matching [query].
  ///
  /// Returns an empty list when the trimmed [query] is shorter than
  /// [minQueryLength] or nothing matches. Throws a [CatalogException] if the
  /// request fails.
  Future<List<CatalogAnime>> search(String query, {int limit = 20});

  /// Returns the anime with the given MyAnimeList id.
  ///
  /// Throws a [CatalogNotFoundException] if the catalog has no anime with
  /// [malId], and another [CatalogException] if the request fails.
  Future<CatalogAnime> byId(int malId);

  /// Returns the anime airing in the [season] of [year]: those that premiere
  /// in it, including the ones not aired yet, and those still airing from
  /// earlier seasons.
  ///
  /// Only series are listed, not films, specials or music videos. Throws a
  /// [CatalogException] if the request fails.
  Future<List<CatalogAnime>> airingIn(int year, AnimeSeason season);
}
