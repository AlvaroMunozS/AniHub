import 'package:anihub/domain/entities/anime_relation_node.dart';
import 'package:anihub/domain/ports/anime_relations.dart';

/// Offline [AnimeRelations] that serves the requested subset of [graph], or
/// throws [error] to simulate a failing source.
class FakeAnimeRelations implements AnimeRelations {
  FakeAnimeRelations({this.graph, this.error});

  final Map<int, AnimeRelationNode>? graph;

  final Object? error;

  int callCount = 0;

  List<int> lastRequestedIds = const <int>[];

  @override
  Future<Map<int, AnimeRelationNode>> forIds(Iterable<int> malIds) async {
    callCount++;
    lastRequestedIds = List<int>.unmodifiable(malIds);
    if (error != null) throw error!;
    final Map<int, AnimeRelationNode> source =
        graph ?? const <int, AnimeRelationNode>{};
    final Map<int, AnimeRelationNode> result = <int, AnimeRelationNode>{};
    for (final int id in malIds) {
      final AnimeRelationNode? node = source[id];
      if (node != null) result[id] = node;
    }
    return result;
  }
}
