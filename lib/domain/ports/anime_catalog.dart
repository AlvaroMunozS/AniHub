import '../entities/catalog_anime.dart';
import '../errors/catalog_exception.dart';

/// Read-only access to anime metadata.
abstract interface class AnimeCatalog {
  /// Returns up to [limit] anime matching [query].
  ///
  /// Returns an empty list when [query] is blank or nothing matches. Throws a
  /// [CatalogException] if the request fails.
  Future<List<CatalogAnime>> search(String query, {int limit = 20});

  /// Returns the anime with the given MyAnimeList id.
  ///
  /// Throws a [CatalogException] if the id is unknown or the request fails.
  Future<CatalogAnime> byId(int malId);
}
