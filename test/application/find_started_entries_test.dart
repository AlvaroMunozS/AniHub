import 'package:anihub/application/usecases/usecases.dart';
import 'package:anihub/domain/entities/anime_relation.dart';
import 'package:anihub/domain/entities/anime_relation_node.dart';
import 'package:anihub/domain/entities/entry.dart';
import 'package:anihub/domain/values/relation_kind.dart';
import 'package:anihub/domain/values/watch_status.dart';
import 'package:flutter_test/flutter_test.dart';

Entry _entry(int malId, WatchStatus status) {
  return Entry(
    malId: malId,
    title: 'Anime $malId',
    status: status,
    updatedAt: DateTime(2024),
  );
}

AnimeRelationNode _node(int malId, Map<int, RelationKind> edges) {
  return AnimeRelationNode(
    malId: malId,
    title: 'Anime $malId',
    relations: <AnimeRelation>[
      for (final MapEntry<int, RelationKind> edge in edges.entries)
        AnimeRelation(malId: edge.key, kind: edge.value, title: 'x'),
    ],
  );
}

void main() {
  const FindStartedEntries findStarted = FindStartedEntries();

  test('a completed member starts its franchise', () {
    final List<Entry> library = <Entry>[
      _entry(1, WatchStatus.completed),
      _entry(2, WatchStatus.planned),
    ];
    final Map<int, AnimeRelationNode> relations = <int, AnimeRelationNode>{
      1: _node(1, <int, RelationKind>{2: RelationKind.sequel}),
    };

    expect(findStarted(library, relations), <int>{1, 2});
  });

  test('a watched member starts its franchise', () {
    final List<Entry> library = <Entry>[
      _entry(1, WatchStatus.watching),
      _entry(2, WatchStatus.planned),
    ];
    final Map<int, AnimeRelationNode> relations = <int, AnimeRelationNode>{
      2: _node(2, <int, RelationKind>{1: RelationKind.prequel}),
    };

    expect(findStarted(library, relations), <int>{1, 2});
  });

  test('a franchise with only planned members is not started', () {
    final List<Entry> library = <Entry>[
      _entry(1, WatchStatus.planned),
      _entry(2, WatchStatus.planned),
      _entry(3, WatchStatus.completed),
    ];
    final Map<int, AnimeRelationNode> relations = <int, AnimeRelationNode>{
      1: _node(1, <int, RelationKind>{2: RelationKind.sequel}),
    };

    expect(findStarted(library, relations), <int>{3});
  });

  test('connects through an anime missing from the library', () {
    // 1 -> 2 -> 3, where 2 is not in the library.
    final List<Entry> library = <Entry>[
      _entry(1, WatchStatus.completed),
      _entry(3, WatchStatus.planned),
    ];
    final Map<int, AnimeRelationNode> relations = <int, AnimeRelationNode>{
      1: _node(1, <int, RelationKind>{2: RelationKind.sequel}),
      3: _node(3, <int, RelationKind>{2: RelationKind.prequel}),
    };

    expect(findStarted(library, relations), <int>{1, 3});
  });

  test('a spin-off belongs to the franchise', () {
    final List<Entry> library = <Entry>[
      _entry(1, WatchStatus.completed),
      _entry(2, WatchStatus.planned),
    ];
    final Map<int, AnimeRelationNode> relations = <int, AnimeRelationNode>{
      1: _node(1, <int, RelationKind>{2: RelationKind.spinOff}),
    };

    expect(findStarted(library, relations), <int>{1, 2});
  });

  test('character and other edges do not connect a franchise', () {
    final List<Entry> library = <Entry>[
      _entry(1, WatchStatus.completed),
      _entry(2, WatchStatus.planned),
      _entry(3, WatchStatus.planned),
    ];
    final Map<int, AnimeRelationNode> relations = <int, AnimeRelationNode>{
      1: _node(1, <int, RelationKind>{
        2: RelationKind.character,
        3: RelationKind.other,
      }),
    };

    expect(findStarted(library, relations), <int>{1});
  });

  test('judges each entry alone without a graph', () {
    final List<Entry> library = <Entry>[
      _entry(1, WatchStatus.completed),
      _entry(2, WatchStatus.planned),
      _entry(3, WatchStatus.watching),
    ];

    expect(findStarted(library, const <int, AnimeRelationNode>{}), <int>{1, 3});
  });
}
