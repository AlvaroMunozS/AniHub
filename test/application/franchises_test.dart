import 'package:anihub/application/usecases/usecases.dart';
import 'package:anihub/domain/entities/anime_relation.dart';
import 'package:anihub/domain/entities/anime_relation_node.dart';
import 'package:anihub/domain/entities/entry.dart';
import 'package:anihub/domain/values/relation_kind.dart';
import 'package:anihub/domain/values/watch_status.dart';
import 'package:flutter_test/flutter_test.dart';

Entry _entry(int malId) {
  return Entry(
    malId: malId,
    title: 'Anime $malId',
    status: WatchStatus.planned,
    updatedAt: DateTime(2024),
  );
}

void main() {
  test('roots a franchise at its lowest id, even one outside the library', () {
    // 5 -> 2 -> 9, where 2 is not in the library.
    final Map<int, AnimeRelationNode> relations = <int, AnimeRelationNode>{
      9: const AnimeRelationNode(
        malId: 9,
        title: 'Anime 9',
        relations: <AnimeRelation>[
          AnimeRelation(malId: 2, kind: RelationKind.prequel, title: 'x'),
        ],
      ),
      5: const AnimeRelationNode(
        malId: 5,
        title: 'Anime 5',
        relations: <AnimeRelation>[
          AnimeRelation(malId: 2, kind: RelationKind.sequel, title: 'x'),
        ],
      ),
    };

    final Franchises franchises = Franchises(<Entry>[
      _entry(9),
      _entry(5),
    ], relations);

    expect(franchises.rootOf(9), 2);
    expect(franchises.rootOf(5), 2);
  });

  test('roots an entry without edges at itself', () {
    final Franchises franchises = Franchises(<Entry>[
      _entry(7),
    ], const <int, AnimeRelationNode>{});

    expect(franchises.rootOf(7), 7);
  });

  test('roots an id it never saw at itself', () {
    final Franchises franchises = Franchises(
      const <Entry>[],
      const <int, AnimeRelationNode>{},
    );

    expect(franchises.rootOf(42), 42);
  });
}
