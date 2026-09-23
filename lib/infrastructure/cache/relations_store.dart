import 'relations_cache_codec.dart';

/// Persistent storage of cached relation nodes, keyed by MyAnimeList id.
abstract interface class RelationsStore {
  /// Returns every stored node.
  Future<Map<int, CachedRelationNode>> loadAll();

  /// Inserts [nodes], replacing any stored node with the same id, in a
  /// single transaction.
  Future<void> saveAll(Map<int, CachedRelationNode> nodes);

  /// Deletes the nodes saved before [cutoff].
  Future<void> deleteSavedBefore(DateTime cutoff);
}
