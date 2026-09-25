import 'package:anihub/application/usecases/usecases.dart';
import 'package:anihub/domain/entities/anime_relation.dart';
import 'package:anihub/domain/entities/anime_relation_node.dart';
import 'package:anihub/domain/errors/catalog_exception.dart';
import 'package:anihub/domain/ports/anime_relations.dart';
import 'package:anihub/domain/values/relation_kind.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_anime_relations.dart';

AnimeRelationNode _node(int malId, Map<int, RelationKind> edges) {
  return AnimeRelationNode(
    malId: malId,
    title: 'Anime $malId',
    relations: <AnimeRelation>[
      for (final MapEntry<int, RelationKind>(:int key, :value) in edges.entries)
        AnimeRelation(malId: key, kind: value, title: 'Anime $key'),
    ],
  );
}

/// Seasons 1 to 4 chained by sequel and prequel edges.
Map<int, AnimeRelationNode> _seasons() => <int, AnimeRelationNode>{
  1: _node(1, <int, RelationKind>{2: RelationKind.sequel}),
  2: _node(2, <int, RelationKind>{
    1: RelationKind.prequel,
    3: RelationKind.sequel,
  }),
  3: _node(3, <int, RelationKind>{
    2: RelationKind.prequel,
    4: RelationKind.sequel,
  }),
  4: _node(4, <int, RelationKind>{3: RelationKind.prequel}),
};

/// Records every lookup, delegating to [FakeAnimeRelations].
class _Recording implements AnimeRelations {
  _Recording(Map<int, AnimeRelationNode> graph, {this.failOn = const {}})
    : _inner = FakeAnimeRelations(graph: graph);

  final FakeAnimeRelations _inner;

  /// Ids whose lookup throws [error].
  final Set<int> failOn;

  Object error = const CatalogNetworkException('offline');

  final List<List<int>> requests = <List<int>>[];

  @override
  Future<Map<int, AnimeRelationNode>> forIds(Iterable<int> malIds) {
    final List<int> ids = List<int>.of(malIds);
    requests.add(ids);
    if (ids.any(failOn.contains)) throw error;
    return _inner.forIds(ids);
  }
}

Map<int, AnimeRelationNode> _only(
  Map<int, AnimeRelationNode> graph,
  Iterable<int> ids,
) => <int, AnimeRelationNode>{for (final int id in ids) id: graph[id]!};

void main() {
  test('links seasons 1 and 4 through missing seasons 2 and 3', () async {
    final Map<int, AnimeRelationNode> seasons = _seasons();
    final _Recording relations = _Recording(seasons);

    final FranchiseChains chains = await LinkFranchiseChains(relations)(
      _only(seasons, <int>[1, 4]),
      <int>{1, 4},
    );

    expect(chains.graph.keys, unorderedEquals(<int>[1, 2, 3, 4]));
    expect(chains.complete, isTrue);
    expect(relations.requests, <List<int>>[
      <int>[2, 3],
    ]);
  });

  test('follows a chain round by round until it closes', () async {
    final Map<int, AnimeRelationNode> seasons = _seasons();
    final _Recording relations = _Recording(seasons);

    final FranchiseChains chains = await LinkFranchiseChains(relations)(
      _only(seasons, <int>[1]),
      <int>{1},
    );

    expect(chains.graph.keys, unorderedEquals(<int>[1, 2, 3, 4]));
    expect(relations.requests, <List<int>>[
      <int>[2],
      <int>[3],
      <int>[4],
    ]);
  });

  test('follows only sequel and prequel edges', () async {
    final Map<int, AnimeRelationNode> graph = <int, AnimeRelationNode>{
      1: _node(1, <int, RelationKind>{
        2: RelationKind.sideStory,
        3: RelationKind.spinOff,
        4: RelationKind.alternativeVersion,
      }),
    };
    final _Recording relations = _Recording(graph);

    final FranchiseChains chains = await LinkFranchiseChains(relations)(
      graph,
      <int>{1},
    );

    expect(chains.graph, graph);
    expect(chains.complete, isTrue);
    expect(relations.requests, isEmpty);
  });

  test('never requests library ids, even when the graph lacks them', () async {
    final Map<int, AnimeRelationNode> seasons = _seasons();
    final _Recording relations = _Recording(seasons);

    final FranchiseChains chains = await LinkFranchiseChains(relations)(
      _only(seasons, <int>[1]),
      <int>{1, 2},
    );

    expect(chains.graph.keys, <int>[1]);
    expect(relations.requests, isEmpty);
  });

  test('stops at the cap, requesting the lowest ids first', () async {
    final Map<int, AnimeRelationNode> graph = <int, AnimeRelationNode>{
      1: _node(1, <int, RelationKind>{
        30: RelationKind.sequel,
        10: RelationKind.sequel,
        20: RelationKind.prequel,
      }),
      10: _node(10, <int, RelationKind>{11: RelationKind.sequel}),
      20: _node(20, const <int, RelationKind>{}),
      30: _node(30, const <int, RelationKind>{}),
      11: _node(11, const <int, RelationKind>{}),
    };
    final _Recording relations = _Recording(graph);

    final FranchiseChains chains = await LinkFranchiseChains(
      relations,
      maxExtraIds: 3,
    )(_only(graph, <int>[1]), <int>{1});

    expect(relations.requests, <List<int>>[
      <int>[10, 20, 30],
    ]);
    expect(chains.graph.keys, unorderedEquals(<int>[1, 10, 20, 30]));
    expect(chains.complete, isTrue);
  });

  test('returns what it fetched when a lookup fails', () async {
    final Map<int, AnimeRelationNode> seasons = _seasons();
    final _Recording relations = _Recording(seasons, failOn: <int>{3});

    final FranchiseChains chains = await LinkFranchiseChains(relations)(
      _only(seasons, <int>[1]),
      <int>{1},
    );

    expect(chains.graph.keys, unorderedEquals(<int>[1, 2]));
    expect(chains.complete, isFalse);
  });

  test('is incomplete when the catalog does not return an id', () async {
    final Map<int, AnimeRelationNode> graph = <int, AnimeRelationNode>{
      1: _node(1, <int, RelationKind>{2: RelationKind.sequel}),
    };

    final FranchiseChains chains = await LinkFranchiseChains(_Recording(graph))(
      graph,
      <int>{1},
    );

    expect(chains.graph, graph);
    expect(chains.complete, isFalse);
  });

  test('rethrows errors that are not catalog failures', () async {
    final Map<int, AnimeRelationNode> seasons = _seasons();
    final _Recording relations = _Recording(seasons, failOn: <int>{2})
      ..error = StateError('bug');

    await expectLater(
      LinkFranchiseChains(relations)(_only(seasons, <int>[1]), <int>{1}),
      throwsStateError,
    );
  });

  test('leaves the given graph untouched', () async {
    final Map<int, AnimeRelationNode> seasons = _seasons();
    final Map<int, AnimeRelationNode> graph = _only(seasons, <int>[1]);

    await LinkFranchiseChains(_Recording(seasons))(graph, <int>{1});

    expect(graph.keys, <int>[1]);
  });
}
