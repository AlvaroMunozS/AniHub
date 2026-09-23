import 'package:anihub/domain/entities/catalog_anime.dart';
import 'package:anihub/domain/errors/catalog_exception.dart';
import 'package:anihub/domain/ports/anime_catalog.dart';

import 'sample_data.dart';

/// Offline [AnimeCatalog] that matches titles by case-insensitive substring,
/// over [sampleCatalog] by default.
///
/// When [error] is set, every request throws it instead.
class FakeAnimeCatalog implements AnimeCatalog {
  FakeAnimeCatalog({List<CatalogAnime>? catalog, this.error})
    : _catalog = catalog ?? sampleCatalog;

  final List<CatalogAnime> _catalog;
  final Object? error;

  @override
  Future<List<CatalogAnime>> search(String query, {int limit = 20}) async {
    if (error case final Object error) throw error;
    final String q = query.trim().toLowerCase();
    if (q.isEmpty) return const <CatalogAnime>[];
    final List<CatalogAnime> hits = _catalog
        .where((CatalogAnime a) => a.title.toLowerCase().contains(q))
        .take(limit)
        .toList();
    return List<CatalogAnime>.unmodifiable(hits);
  }

  @override
  Future<CatalogAnime> byId(int malId) async {
    if (error case final Object error) throw error;
    return _catalog.firstWhere(
      (CatalogAnime a) => a.malId == malId,
      orElse: () => throw CatalogResponseException('Anime $malId not found'),
    );
  }
}
