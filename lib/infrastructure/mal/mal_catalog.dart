import 'dart:math';

import '../../domain/entities/catalog_anime.dart';
import '../../domain/errors/catalog_exception.dart';
import '../../domain/ports/anime_catalog.dart';
import '../../domain/values/anime_season.dart';
import 'mal_client.dart';
import 'mal_mapping.dart';

/// [AnimeCatalog] backed by the MyAnimeList API.
///
/// Queries shorter than [minQueryLength] return no results without a request,
/// because MyAnimeList rejects them. Search sends `nsfw=true` because without
/// it MyAnimeList also leaves out anime rated `gray`, which includes ordinary
/// films and series; results rated `black` are hentai, which the app does not
/// list. A search result without an id or a title is skipped.
///
/// The season endpoint only lists the anime that premiere in that season, so
/// [airingIn] adds the `airing` ranking, which holds everything currently
/// airing whenever it started.
class MalCatalog implements AnimeCatalog {
  MalCatalog(this._client);

  // MyAnimeList rejects shorter queries with HTTP 400.
  @override
  int get minQueryLength => 3;

  static const int _maxLimit = 100;

  static const String _searchFields =
      'alternative_titles,num_episodes,status,start_season,start_date';

  static const String _detailFields = '$_searchFields,synopsis,genres,studios';

  static const String _airingFields =
      '$_searchFields,nsfw,media_type,broadcast';

  /// Media types listed by [airingIn]; the rest are films, specials, music
  /// videos and commercials.
  static const Set<String> _seriesTypes = <String>{'tv', 'ona'};

  /// Page size of the season and ranking lists, which allow more than
  /// search.
  static const int _airingPageSize = 500;

  /// Pages read per airing list. A season holds a few hundred anime, so the
  /// second page is a margin that is rarely requested.
  static const int _maxAiringPages = 2;

  final MalClient _client;

  // Avoids repeating a request while the user edits a search.
  final Map<String, List<CatalogAnime>> _searchCache =
      <String, List<CatalogAnime>>{};

  @override
  Future<List<CatalogAnime>> search(String query, {int limit = 20}) async {
    final String term = query.trim();
    if (term.length < minQueryLength) return const <CatalogAnime>[];

    final String cacheKey = '${term.toLowerCase()}#$limit';
    if (_searchCache[cacheKey] case final List<CatalogAnime> cached) {
      return cached;
    }

    final Map<String, Object?>? body = await _client.get(
      'anime',
      <String, String>{
        'q': term,
        'limit': '${min(limit, _maxLimit)}',
        'fields': '$_searchFields,nsfw',
        'nsfw': 'true',
      },
    );
    final List<CatalogAnime> results = List<CatalogAnime>.unmodifiable(
      _nodesOf(body).map(_toCatalogAnime),
    );

    return _searchCache[cacheKey] = results;
  }

  @override
  Future<CatalogAnime> byId(int malId) async {
    final Map<String, Object?>? body = await _client.get(
      'anime/$malId',
      <String, String>{'fields': _detailFields},
    );
    if (body == null) throw CatalogNotFoundException(malId);
    return _toCatalogAnime(body);
  }

  @override
  Future<List<CatalogAnime>> airingIn(int year, AnimeSeason season) async {
    final List<List<Map<String, Object?>>> lists = await Future.wait(
      <Future<List<Map<String, Object?>>>>[
        _airingList('anime/season/$year/${season.name}', <String, String>{}),
        _airingList('anime/ranking', <String, String>{
          'ranking_type': 'airing',
        }),
      ],
    );
    final Map<int, CatalogAnime> byId = <int, CatalogAnime>{};
    for (final Map<String, Object?> node in lists.expand((l) => l)) {
      if (!_seriesTypes.contains(node['media_type']) ||
          node['status'] == 'finished_airing') {
        continue;
      }
      byId.putIfAbsent(parseId(node), () => _toCatalogAnime(node));
    }
    return List<CatalogAnime>.unmodifiable(byId.values);
  }

  Future<List<Map<String, Object?>>> _airingList(
    String path,
    Map<String, String> query,
  ) async {
    final List<Map<String, Object?>> nodes = <Map<String, Object?>>[];
    for (int page = 0; page < _maxAiringPages; page++) {
      final Map<String, Object?>? body = await _client.get(
        path,
        <String, String>{
          ...query,
          'limit': '$_airingPageSize',
          'offset': '${page * _airingPageSize}',
          'fields': _airingFields,
          'nsfw': 'true',
        },
      );
      nodes.addAll(_nodesOf(body));
      if (body case {'paging': {'next': String()}}) continue;
      break;
    }
    return nodes;
  }

  /// Returns the anime nodes of a list response, skipping those without an
  /// id or a title and those rated `black`.
  static Iterable<Map<String, Object?>> _nodesOf(Map<String, Object?>? body) {
    return switch (body) {
      {'data': final List<Object?> data} => <Map<String, Object?>>[
        for (final Object? item in data)
          if (item case {'node': final Map<String, Object?> node}
              when node['id'] is int &&
                  parseTitle(node) != null &&
                  node['nsfw'] != 'black')
            node,
      ],
      _ => throw const CatalogResponseException('Malformed list response'),
    };
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
      broadcast: parseBroadcast(node),
    );
  }
}
