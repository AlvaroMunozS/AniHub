import '../entities/catalog_anime.dart';
import '../errors/catalog_exception.dart';

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
}
