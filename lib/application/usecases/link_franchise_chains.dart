import '../../domain/entities/anime_relation.dart';
import '../../domain/entities/anime_relation_node.dart';
import '../../domain/errors/catalog_exception.dart';
import '../../domain/ports/anime_relations.dart';
import '../../domain/values/relation_kind.dart';

/// A relation graph extended along sequel and prequel chains.
class FranchiseChains {
  const FranchiseChains(this.graph, {required this.complete});

  final Map<int, AnimeRelationNode> graph;

  /// Whether every requested anime was fetched.
  ///
  /// False when a lookup failed or left requested ids out. Stopping at
  /// `LinkFranchiseChains.maxExtraIds` still counts as complete, because
  /// fetching again would stop at the same point.
  final bool complete;
}

/// Fetches the anime between library entries of the same franchise.
///
/// MyAnimeList has no franchise id, so seasons 1 and 4 are linked only
/// through the nodes of seasons 2 and 3. Only sequel and prequel edges are
/// followed: following every edge that groups a franchise grows to hundreds
/// of requests in franchises with many side stories and spin-offs.
class LinkFranchiseChains {
  const LinkFranchiseChains(this._relations, {this.maxExtraIds = 100})
    : assert(maxExtraIds >= 0, 'maxExtraIds must not be negative');

  final AnimeRelations _relations;

  /// Most anime requested per call, beyond the graph and the library it
  /// receives.
  final int maxExtraIds;

  /// Returns [graph] with the nodes reached by following the sequel and
  /// prequel edges that leave it, round by round, until the chains close or
  /// [maxExtraIds] anime have been requested.
  ///
  /// [libraryIds] are never requested, even when [graph] lacks them. Each
  /// round requests the lowest ids first, so a franchise over the cap is
  /// always cut at the same point. A [CatalogException] ends the traversal
  /// with what was fetched so far; any other error is rethrown. [graph] is
  /// not modified.
  Future<FranchiseChains> call(
    Map<int, AnimeRelationNode> graph,
    Set<int> libraryIds,
  ) async {
    final Map<int, AnimeRelationNode> extended = Map<int, AnimeRelationNode>.of(
      graph,
    );
    final Set<int> known = <int>{...graph.keys, ...libraryIds};
    List<int> frontier = _nextIds(graph.values, known);
    int budget = maxExtraIds;
    bool complete = true;

    while (frontier.isNotEmpty && budget > 0) {
      final List<int> batch = frontier.take(budget).toList(growable: false);
      budget -= batch.length;
      known.addAll(batch);
      final Map<int, AnimeRelationNode> fetched;
      try {
        fetched = await _relations.forIds(batch);
      } on CatalogException {
        complete = false;
        break;
      }
      if (!batch.every(fetched.containsKey)) complete = false;
      extended.addAll(fetched);
      frontier = _nextIds(fetched.values, known);
    }
    return FranchiseChains(extended, complete: complete);
  }
}

/// Sorted ids of the sequel and prequel edges of [nodes] outside [known].
List<int> _nextIds(Iterable<AnimeRelationNode> nodes, Set<int> known) {
  return <int>{
    for (final AnimeRelationNode node in nodes)
      for (final AnimeRelation relation in node.relations)
        if (_follows(relation.kind) && !known.contains(relation.malId))
          relation.malId,
  }.toList()..sort();
}

bool _follows(RelationKind kind) =>
    kind == RelationKind.sequel || kind == RelationKind.prequel;
