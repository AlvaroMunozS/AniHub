import 'dart:math';

import '../../domain/entities/catalog_anime.dart';
import '../../domain/errors/catalog_exception.dart';
import '../../domain/ports/anime_catalog.dart';
import 'mal_client.dart';
import 'mal_mapping.dart';

/// [AnimeCatalog] backed by the MyAnimeList API.
///
/// Queries shorter than three characters return no results without a request,
/// because MyAnimeList rejects them. MyAnimeList leaves anime rated not safe
/// for work out of search results because `nsfw=true` is never sent. A search
/// result without an id or a title is skipped.
class MalCatalog implements AnimeCatalog {
  MalCatalog(this._client);

  static const int _minQueryLength = 3;

  static const int _maxLimit = 100;

  static const String _searchFields =
      'alternative_titles,num_episodes,status,start_season,start_date';

  static const String _detailFields = '$_searchFields,synopsis,genres,studios';

  final MalClient _client;

  // Avoids repeating a request while the user edits a search.
  final Map<String, List<CatalogAnime>> _searchCache =
      <String, List<CatalogAnime>>{};

  @override
  Future<List<CatalogAnime>> search(String query, {int limit = 20}) async {
    final String term = query.trim();
    if (term.length < _minQueryLength) return const <CatalogAnime>[];

    final String cacheKey = '${term.toLowerCase()}#$limit';
    if (_searchCache[cacheKey] case final List<CatalogAnime> cached) {
      return cached;
    }

    final Map<String, Object?>? body = await _client.get(
      'anime',
      <String, String>{
        'q': term,
        'limit': '${min(limit, _maxLimit)}',
        'fields': _searchFields,
      },
    );
    final List<CatalogAnime> results = switch (body) {
      {'data': final List<Object?> data} => List<CatalogAnime>.unmodifiable(
        <CatalogAnime>[
          for (final Object? item in data)
            if (item case {'node': final Map<String, Object?> node}
                when node['id'] is int && parseTitle(node) != null)
              _toCatalogAnime(node),
        ],
      ),
      _ => throw const CatalogResponseException('Malformed search response'),
    };

    return _searchCache[cacheKey] = results;
  }

  @override
  Future<CatalogAnime> byId(int malId) async {
    final Map<String, Object?>? body = await _client.get(
      'anime/$malId',
      <String, String>{'fields': _detailFields},
    );
    if (body == null) {
      throw CatalogResponseException('Anime $malId not found');
    }
    return _toCatalogAnime(body);
  }

  static CatalogAnime _toCatalogAnime(Map<String, Object?> node) {
    final int id = parseId(node);
    return CatalogAnime(
      malId: id,
      title: requireTitle(node),
      coverUrl: parseCoverUrl(node),
      totalEpisodes: switch (node) {
        // MyAnimeList reports 0 when the count is not known yet.
        {'num_episodes': final int count} when count > 0 => count,
        _ => null,
      },
      seasonYear: parseYear(node),
      season: parseSeason(node),
      isAiring: node['status'] == 'currently_airing',
      description: switch (node) {
        {'synopsis': final String text} when text.trim().isNotEmpty =>
          text.trim(),
        _ => null,
      },
      genres: List<String>.unmodifiable(<String>[
        if (node case {'genres': final List<Object?> genres})
          for (final Object? genre in genres)
            if (genre case {'name': final String name}) name,
      ]),
      studioName: switch (node) {
        {'studios': [{'name': final String name}, ...]} => name,
        _ => null,
      },
    );
  }
}
