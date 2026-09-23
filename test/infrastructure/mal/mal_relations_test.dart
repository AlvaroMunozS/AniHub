import 'package:anihub/domain/entities/anime_relation.dart';
import 'package:anihub/domain/entities/anime_relation_node.dart';
import 'package:anihub/domain/errors/catalog_exception.dart';
import 'package:anihub/domain/values/relation_kind.dart';
import 'package:anihub/domain/values/release_date.dart';
import 'package:anihub/infrastructure/mal/mal_relations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'fake_mal_api.dart';

Map<String, Object?> _edge(int id, String type, {String? title}) =>
    <String, Object?>{
      'node': <String, Object?>{
        'id': id,
        'title': ?title,
        'start_season': <String, Object?>{'year': 2000 + id, 'season': 'fall'},
      },
      'relation_type': type,
    };

Map<String, Object?> _node(int id, List<Map<String, Object?>> edges) =>
    <String, Object?>{
      'id': id,
      'title': 'Anime $id',
      'start_date': '2011-04-06',
      'related_anime': edges,
    };

/// Answers `anime/{id}` with [nodes], or 404 for other ids.
FakeMalApi _api(Map<int, Map<String, Object?>> nodes) =>
    FakeMalApi((Uri url) async {
      final int id = int.parse(url.pathSegments.last);
      return nodes[id] == null
          ? jsonResponse(<String, Object?>{'error': 'not_found'}, 404)
          : jsonResponse(nodes[id]);
    });

void main() {
  test('maps a node with its release date and relations', () async {
    final FakeMalApi api = _api(<int, Map<String, Object?>>{
      10: _node(10, <Map<String, Object?>>[
        _edge(11, 'sequel', title: 'Anime 11'),
        _edge(12, 'character', title: 'Anime 12'),
      ]),
    });

    final Map<int, AnimeRelationNode> result = await MalRelations(api.client())
        .forIds(<int>[10]);

    expect(
      result[10],
      const AnimeRelationNode(
        malId: 10,
        title: 'Anime 10',
        seasonYear: 2011,
        startDate: ReleaseDate(year: 2011, month: 4, day: 6),
        relations: <AnimeRelation>[
          AnimeRelation(
            malId: 11,
            kind: RelationKind.sequel,
            title: 'Anime 11',
            seasonYear: 2011,
          ),
          AnimeRelation(
            malId: 12,
            kind: RelationKind.character,
            title: 'Anime 12',
            seasonYear: 2012,
          ),
        ],
      ),
    );
    expect(
      api.requests.single.queryParameters['fields'],
      contains('related_anime{node{'),
    );
  });

  test('drops self references, unknown relation types and untitled '
      'nodes', () async {
    final FakeMalApi api = _api(<int, Map<String, Object?>>{
      10: _node(10, <Map<String, Object?>>[
        _edge(10, 'sequel', title: 'Anime 10'),
        _edge(11, 'future_relation_type', title: 'Anime 11'),
        _edge(12, 'prequel'),
        _edge(13, 'prequel', title: 'Anime 13'),
      ]),
    });

    final Map<int, AnimeRelationNode> result = await MalRelations(api.client())
        .forIds(<int>[10]);

    expect(result[10]!.relations.map((AnimeRelation r) => r.malId), <int>[13]);
  });

  test('leaves unknown ids out of the result', () async {
    final FakeMalApi api = _api(<int, Map<String, Object?>>{
      1: _node(1, const <Map<String, Object?>>[]),
    });

    final Map<int, AnimeRelationNode> result = await MalRelations(api.client())
        .forIds(<int>[1, 2]);

    expect(result.keys, <int>[1]);
  });

  test('requests each distinct id once and nothing for no ids', () async {
    final FakeMalApi api = _api(<int, Map<String, Object?>>{
      1: _node(1, const <Map<String, Object?>>[]),
    });
    final MalRelations relations = MalRelations(api.client());

    expect(await relations.forIds(const <int>[]), isEmpty);
    await relations.forIds(<int>[1, 1, 1]);

    expect(api.requests, hasLength(1));
  });

  test('keeps at most concurrency requests in flight', () async {
    int inFlight = 0;
    int maxInFlight = 0;
    final FakeMalApi api = FakeMalApi((Uri url) async {
      inFlight++;
      maxInFlight = inFlight > maxInFlight ? inFlight : maxInFlight;
      await Future<void>.delayed(Duration.zero);
      inFlight--;
      final int id = int.parse(url.pathSegments.last);
      return jsonResponse(_node(id, const <Map<String, Object?>>[]));
    });

    final Map<int, AnimeRelationNode> result = await MalRelations(
      api.client(),
      concurrency: 3,
    ).forIds(List<int>.generate(10, (int i) => i + 1));

    expect(result, hasLength(10));
    expect(maxInFlight, 3);
  });

  test('rethrows a failure and starts no new requests after it', () async {
    final FakeMalApi api = FakeMalApi((Uri url) async {
      if (url.pathSegments.last == '1') return http.Response('', 500);
      await Future<void>.delayed(Duration.zero);
      final int id = int.parse(url.pathSegments.last);
      return jsonResponse(_node(id, const <Map<String, Object?>>[]));
    });

    await expectLater(
      MalRelations(
        api.client(),
        concurrency: 2,
      ).forIds(List<int>.generate(10, (int i) => i + 1)),
      throwsA(isA<CatalogResponseException>()),
    );
    expect(api.requests, hasLength(2));
  });
}
