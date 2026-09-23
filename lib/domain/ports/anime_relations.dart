import '../entities/anime_relation_node.dart';

/// Read-only access to the relation graph between anime.
abstract interface class AnimeRelations {
  /// Returns the direct relations of each of [malIds], keyed by id.
  ///
  /// Only the edges of the requested ids are returned, not those of their
  /// neighbors. Unknown ids are absent from the result, and an empty
  /// [malIds] returns an empty map without a network request. Edges to
  /// media that are not anime and unrecognized relation types are dropped.
  Future<Map<int, AnimeRelationNode>> forIds(Iterable<int> malIds);
}
