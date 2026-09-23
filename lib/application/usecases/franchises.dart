import '../../domain/entities/anime_relation_node.dart';
import '../../domain/entities/entry.dart';

/// Franchises of the library: the connected components of the relation
/// graph along the edges whose kind satisfies `RelationKind.groupsFranchise`.
///
/// Entries connected through anime missing from the library still share a
/// franchise, so seasons 1 and 3 share one without season 2. An entry with
/// no such edges is a franchise of its own.
class Franchises {
  Franchises(List<Entry> entries, Map<int, AnimeRelationNode> relations) {
    for (final Entry entry in entries) {
      _add(entry.malId);
    }
    for (final AnimeRelationNode node in relations.values) {
      for (final relation in node.relations) {
        if (!relation.kind.groupsFranchise) continue;
        _add(node.malId);
        _add(relation.malId);
        _union(node.malId, relation.malId);
      }
    }
  }

  final Map<int, int> _parent = <int, int>{};

  /// The lowest MyAnimeList id in the franchise of [malId], so it is stable
  /// for the same graph.
  int rootOf(int malId) {
    int root = _parent[malId] ?? malId;
    while (root != (_parent[root] ?? root)) {
      root = _parent[root]!;
    }
    int current = malId;
    while (current != root) {
      final int next = _parent[current]!;
      _parent[current] = root;
      current = next;
    }
    return root;
  }

  void _add(int id) {
    _parent.putIfAbsent(id, () => id);
  }

  void _union(int a, int b) {
    final int rootA = rootOf(a);
    final int rootB = rootOf(b);
    if (rootA == rootB) return;
    if (rootA < rootB) {
      _parent[rootB] = rootA;
    } else {
      _parent[rootA] = rootB;
    }
  }
}
