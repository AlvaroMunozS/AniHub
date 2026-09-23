import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../domain/entities/anime_relation_node.dart';
import '../../domain/errors/catalog_exception.dart';
import '../../domain/ports/anime_relations.dart';
import 'relations_cache_codec.dart';
import 'relations_store.dart';

/// [AnimeRelations] decorator that persists the relation graph on disk.
///
/// Freshness is tracked per node rather than per snapshot, because the cache
/// also holds anime outside the library that were only opened in detail.
/// If every requested id is fresher than [ttl], the network is not touched.
/// Missing and stale ids are fetched [chunkSize] at a time, and each chunk is
/// persisted as it arrives, so a failure part way through a large library
/// keeps what was already fetched. A chunk refused with a
/// [CatalogRateLimitException] is retried once after the wait the source
/// asks for, unless that wait exceeds [maxRetryWait]. Stale cached nodes
/// stand in for the ids that the inner source does not return. An
/// [Exception] from it is rethrown only when nothing was fetched and none of
/// the requested ids has a stale copy; otherwise the partial result is
/// returned. Nodes older than [maxAge] are pruned when the store is loaded
/// and on each write. If the store cannot be loaded, the call fetches every
/// id as if nothing were cached, and the next call tries loading it again.
class CachingAnimeRelations implements AnimeRelations {
  CachingAnimeRelations(
    this._inner,
    this._store, {
    this.ttl = const Duration(days: 30),
    this.maxAge = const Duration(days: 90),
    this.now = DateTime.now,
    this.chunkSize = 25,
    this.maxRetryWait = const Duration(seconds: 30),
    this.wait = _delay,
  }) : assert(chunkSize > 0, 'chunkSize must be positive');

  final AnimeRelations _inner;
  final RelationsStore _store;

  final Duration ttl;

  final Duration maxAge;

  final DateTime Function() now;

  final int chunkSize;

  final Duration maxRetryWait;

  final Future<void> Function(Duration) wait;

  static Future<void> _delay(Duration duration) =>
      Future<void>.delayed(duration);

  // Waits for the time a rate limit asks for before one more attempt.
  // Without a Retry-After header, one second is assumed.
  Future<Map<int, AnimeRelationNode>> _fetchChunk(List<int> chunk) async {
    try {
      return await _inner.forIds(chunk);
    } on CatalogRateLimitException catch (error) {
      final Duration retryAfter =
          error.retryAfter ?? const Duration(seconds: 1);
      if (retryAfter > maxRetryWait) rethrow;
      await wait(retryAfter);
      return _inner.forIds(chunk);
    }
  }

  // Loaded once, and shared by the calls that start before it completes.
  // Merging and pruning happen synchronously on the loaded map so concurrent
  // calls cannot overwrite each other's results. Null inside the future
  // means the load failed.
  Future<Map<int, CachedRelationNode>?>? _loading;

  // Serializes store writes so they never overlap.
  Future<void> _pendingWrite = Future<void>.value();

  Future<Map<int, CachedRelationNode>> _loadNodes() async {
    final Future<Map<int, CachedRelationNode>?> loading = _loading ??=
        _readStore();
    final Map<int, CachedRelationNode>? nodes = await loading;
    if (nodes != null) return nodes;
    // Forgotten so the next call loads again, unless a newer load has
    // already started.
    if (identical(_loading, loading)) _loading = null;
    return <int, CachedRelationNode>{};
  }

  Future<Map<int, CachedRelationNode>?> _readStore() async {
    final Map<int, CachedRelationNode> nodes;
    try {
      nodes = <int, CachedRelationNode>{...await _store.loadAll()};
    } on Object catch (error) {
      // Without the cache the lookup still works, only slower.
      debugPrint('Relations cache not loaded: $error');
      return null;
    }
    // The store may hold nodes that no write has pruned yet, such as those
    // migrated from an older format.
    final DateTime cutoff = now().subtract(maxAge);
    final int loaded = nodes.length;
    nodes.removeWhere(
      (int _, CachedRelationNode cached) => cached.savedAt.isBefore(cutoff),
    );
    if (nodes.length < loaded) {
      unawaited(_persist(() => _store.deleteSavedBefore(cutoff)));
    }
    return nodes;
  }

  Future<void> _persist(Future<void> Function() write) {
    return _pendingWrite = _pendingWrite.then((_) async {
      try {
        await write();
      } on Exception catch (error) {
        // The nodes stay in memory, so the lookup still succeeds.
        debugPrint('Relations cache not saved: $error');
      }
    });
  }

  Future<void> _mergeAndPersist(
    Map<int, CachedRelationNode> nodes,
    Map<int, AnimeRelationNode> fetched,
    DateTime savedAt,
  ) {
    final Map<int, CachedRelationNode> chunk = <int, CachedRelationNode>{
      for (final MapEntry<int, AnimeRelationNode>(:int key, :value)
          in fetched.entries)
        key: CachedRelationNode(savedAt: savedAt, node: value),
    };
    final DateTime cutoff = savedAt.subtract(maxAge);
    nodes
      ..addAll(chunk)
      ..removeWhere(
        (int _, CachedRelationNode cached) => cached.savedAt.isBefore(cutoff),
      );

    return _persist(() async {
      await _store.saveAll(chunk);
      await _store.deleteSavedBefore(cutoff);
    });
  }

  @override
  Future<Map<int, AnimeRelationNode>> forIds(Iterable<int> malIds) async {
    final List<int> ids = malIds.toList(growable: false);
    if (ids.isEmpty) return const <int, AnimeRelationNode>{};

    final Map<int, CachedRelationNode> nodes = await _loadNodes();
    final DateTime requestedAt = now();

    final Map<int, AnimeRelationNode> fresh = <int, AnimeRelationNode>{};
    final Map<int, AnimeRelationNode> stale = <int, AnimeRelationNode>{};
    final List<int> toFetch = <int>[];
    for (final int id in ids) {
      switch (nodes[id]) {
        case final CachedRelationNode cached
            when requestedAt.difference(cached.savedAt) <= ttl:
          fresh[id] = cached.node;
        case final CachedRelationNode cached:
          stale[id] = cached.node;
          toFetch.add(id);
        case null:
          toFetch.add(id);
      }
    }

    if (toFetch.isEmpty) return fresh;

    final Map<int, AnimeRelationNode> fetched = <int, AnimeRelationNode>{};
    for (int start = 0; start < toFetch.length; start += chunkSize) {
      final List<int> chunk = toFetch.sublist(
        start,
        min(start + chunkSize, toFetch.length),
      );
      final Map<int, AnimeRelationNode> result;
      try {
        result = await _fetchChunk(chunk);
      } on Exception {
        if (stale.isEmpty && fetched.isEmpty) rethrow;
        break;
      }
      fetched.addAll(result);
      await _mergeAndPersist(nodes, result, requestedAt);
    }
    return <int, AnimeRelationNode>{...fresh, ...stale, ...fetched};
  }
}
