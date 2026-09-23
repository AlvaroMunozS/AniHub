import 'package:anihub/domain/entities/anime_relation.dart';
import 'package:anihub/domain/entities/anime_relation_node.dart';
import 'package:anihub/domain/values/relation_kind.dart';
import 'package:anihub/domain/values/release_date.dart';
import 'package:anihub/infrastructure/cache/relations_cache_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AnimeRelationNode node({
    int malId = 21,
    String title = 'One Piece',
    List<AnimeRelation> relations = const <AnimeRelation>[],
  }) {
    return AnimeRelationNode(
      malId: malId,
      title: title,
      coverUrl: 'https://example.test/op.jpg',
      seasonYear: 1999,
      startDate: const ReleaseDate(year: 1999, month: 10, day: 20),
      relations: relations,
    );
  }

  test('round-trips a node and its relations', () {
    final AnimeRelationNode original = node(
      relations: const <AnimeRelation>[
        AnimeRelation(
          malId: 5114,
          kind: RelationKind.sequel,
          title: 'FMA',
          coverUrl: 'https://example.test/fma.jpg',
          seasonYear: 2009,
        ),
      ],
    );

    expect(decodeRelationNode(encodeRelationNode(original)), original);
  });

  test('round-trips a node without start date or relations', () {
    const AnimeRelationNode original = AnimeRelationNode(
      malId: 5114,
      title: 'FMA',
    );

    expect(decodeRelationNode(encodeRelationNode(original)), original);
  });

  test('decodes no node from corrupt JSON or a node without an id', () {
    expect(decodeRelationNode('{not json'), isNull);
    expect(decodeRelationNode('[1, 2, 3]'), isNull);
    expect(decodeRelationNode('{"title":"FMA"}'), isNull);
  });

  test('reads the snapshot format of the preferences key', () {
    const String json =
        '{"v":1,"nodes":{"21":{"savedAt":"2024-05-06T00:00:00.000Z",'
        '"node":{"malId":21,"title":"One Piece",'
        '"coverUrl":"https://example.test/op.jpg","seasonYear":1999,'
        '"startDate":{"year":1999,"month":10,"day":20},'
        '"relations":[{"malId":5114,"kind":"sequel","title":"FMA",'
        '"coverUrl":null,"seasonYear":2009}]}}}}';

    expect(decodeRelationsCache(json), <int, CachedRelationNode>{
      21: CachedRelationNode(
        savedAt: DateTime.utc(2024, 5, 6),
        node: node(
          relations: const <AnimeRelation>[
            AnimeRelation(
              malId: 5114,
              kind: RelationKind.sequel,
              title: 'FMA',
              seasonYear: 2009,
            ),
          ],
        ),
      ),
    });
  });

  test('returns null for a missing or different format version', () {
    expect(decodeRelationsCache('{"v":999,"nodes":{}}'), isNull);
    expect(decodeRelationsCache('{"nodes":{}}'), isNull);
  });

  test('returns null for corrupt JSON', () {
    expect(decodeRelationsCache('{not json'), isNull);
    expect(decodeRelationsCache('[1, 2, 3]'), isNull);
    expect(decodeRelationsCache('42'), isNull);
  });

  test('returns null for empty input', () {
    expect(decodeRelationsCache(''), isNull);
  });

  test('drops a relation with an unknown kind and keeps the rest', () {
    const String poisoned =
        '{"v":1,"nodes":{"21":{"savedAt":"2024-01-01T00:00:00.000Z",'
        '"node":{"malId":21,"title":"One Piece","coverUrl":null,'
        '"seasonYear":null,"startDate":null,'
        '"relations":['
        '{"malId":5114,"kind":"sequel","title":"FMA","coverUrl":null,'
        '"seasonYear":null},'
        '{"malId":99,"kind":"not_a_real_kind","title":"?","coverUrl":null,'
        '"seasonYear":null}'
        ']}}}}';

    final Map<int, CachedRelationNode>? decoded = decodeRelationsCache(
      poisoned,
    );

    expect(decoded![21]!.node.relations, const <AnimeRelation>[
      AnimeRelation(malId: 5114, kind: RelationKind.sequel, title: 'FMA'),
    ]);
  });

  test('skips a corrupt node and keeps the rest', () {
    const String mixed =
        '{"v":1,"nodes":{'
        '"21":{"savedAt":"2024-01-01T00:00:00.000Z","node":{"malId":21,'
        '"title":"One Piece"}},'
        '"5114":{"savedAt":"not a date","node":{"malId":5114,'
        '"title":"FMA"}}'
        '}}';

    final Map<int, CachedRelationNode>? decoded = decodeRelationsCache(mixed);

    expect(decoded, <int, CachedRelationNode>{
      21: CachedRelationNode(
        savedAt: DateTime.utc(2024),
        node: const AnimeRelationNode(malId: 21, title: 'One Piece'),
      ),
    });
  });

  test('reads optional fields of the wrong type as absent', () {
    const String json =
        '{"v":1,"nodes":{"21":{"savedAt":"2024-01-01T00:00:00.000Z",'
        '"node":{"malId":21,"title":"One Piece","coverUrl":7,'
        '"seasonYear":"1999","startDate":"1999-10-20","relations":{}}}}}';

    expect(decodeRelationsCache(json), <int, CachedRelationNode>{
      21: CachedRelationNode(
        savedAt: DateTime.utc(2024),
        node: const AnimeRelationNode(malId: 21, title: 'One Piece'),
      ),
    });
  });

  test('skips a node whose key is not an id', () {
    const String json =
        '{"v":1,"nodes":{"one-piece":{"savedAt":"2024-01-01T00:00:00.000Z",'
        '"node":{"malId":21,"title":"One Piece"}}}}';

    expect(decodeRelationsCache(json), isEmpty);
  });
}
