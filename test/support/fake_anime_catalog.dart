import 'package:anihub/domain/entities/catalog_anime.dart';
import 'package:anihub/domain/errors/catalog_exception.dart';
import 'package:anihub/domain/ports/anime_catalog.dart';
import 'package:anihub/domain/values/anime_season.dart';

import 'sample_data.dart';

/// Offline [AnimeCatalog] that matches titles by case-insensitive substring,
/// over [sampleCatalog] by default, and ignores queries shorter than
/// [minQueryLength] like MyAnimeList.
///
/// An unknown id throws [CatalogNotFoundException]. The airing list is
/// [airing], or else the airing anime of the catalog, whatever the season.
/// When [error] is set, searches and lookups throw it instead, and
/// [airingError] does the same for the airing list.
class FakeAnimeCatalog implements AnimeCatalog {
  FakeAnimeCatalog({
    List<CatalogAnime>? catalog,
    this.airing,
    this.error,
    this.airingError,
    this.minQueryLength = 3,
  }) : _catalog = catalog ?? sampleCatalog;

  final List<CatalogAnime> _catalog;
  final List<CatalogAnime>? airing;
  final Object? error;
  Object? airingError;

  /// The seasons [airingIn] was asked for, in order.
  final List<(int, AnimeSeason)> airingRequests = <(int, AnimeSeason)>[];

  @override
  final int minQueryLength;

  @override
  Future<List<CatalogAnime>> search(String query, {int limit = 20}) async {
    if (error case final Object error) throw error;
    final String q = query.trim().toLowerCase();
    if (q.length < minQueryLength) return const <CatalogAnime>[];
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
      orElse: () => throw CatalogNotFoundException(malId),
    );
  }

  @override
  Future<List<CatalogAnime>> airingIn(int year, AnimeSeason season) async {
    airingRequests.add((year, season));
    if (airingError case final Object error) throw error;
    return List<CatalogAnime>.unmodifiable(
      airing ?? _catalog.where((CatalogAnime a) => a.isAiring),
    );
  }
}
