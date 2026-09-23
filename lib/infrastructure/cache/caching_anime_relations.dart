import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../domain/entities/anime_relation_node.dart';
import '../../domain/errors/catalog_exception.dart';
import '../../domain/ports/anime_relations.dart';
import 'relations_cache_codec.dart';
import 'snapshot_store.dart';

/// Preferences key of the relation graph snapshot.
///
/// Renaming it leaves the old value behind in existing installs; an
/// incompatible change to the cache is handled by the format version stored
/// in the snapshot instead.
const String relationsSnapshotKey = 'anihub.relations.cache';

/// [AnimeRelations] decorator that persists the relation graph on disk.
///
/// Freshness is tracked per node rather than per snapshot, because the cache
/// also holds anime outside the library that were only opened in detail.
/// If every requested id is fresher than [ttl], the network is not touched.
/// Missing and stale ids are fetched [chunkSize] at a time, and each chunk is
/// persisted as it arrives, so a failure part way through a large library
/// keeps what was already fetched. A chunk refused with a
/// [CatalogRateLimitException] is retried once after the wait the source
/// asks for, unless that wait exceeds [maxRetryWait]. Stale cached nodes stand in for the ids
/// that the inner source does not return. An [Exception] from it is rethrown
/// only when nothing was fetched and none of the requested ids has a stale
/// copy; otherwise the partial result is returned. Nodes older than [maxAge]
/// are pruned on each write.
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
  final SnapshotStore _store;

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

  // Loaded once. Merging and pruning happen synchronously on this map so
  // concurrent calls cannot overwrite each other's results.
  Map<int, CachedRelationNode>? _nodes;

  // Serializes store writes so they never overlap.
  Future<void> _pendingWrite = Future<void>.value();

  Map<int, CachedRelationNode> _loadNodes() => _nodes ??=
      decodeRelationsCache(_store.read()) ?? <int, CachedRelationNode>{};

  Future<void> _mergeAndPersist(
    Map<int, AnimeRelationNode> fetched,
    DateTime savedAt,
  ) {
    final Map<int, CachedRelationNode> nodes = _loadNodes()
      ..addAll(<int, CachedRelationNode>{
        for (final MapEntry<int, AnimeRelationNode>(:int key, :value)
            in fetched.entries)
          key: CachedRelationNode(savedAt: savedAt, node: value),
      })
      ..removeWhere(
        (int _, CachedRelationNode cached) =>
            savedAt.difference(cached.savedAt) > maxAge,
      );

    return _pendingWrite = _pendingWrite.then((_) async {
      try {
        await _store.write(encodeRelationsCache(nodes));
      } on Exception catch (error) {
        // The previous snapshot stays usable, so the lookup still succeeds.
        debugPrint('Relations cache not saved: $error');
      }
    });
  }

  @override
  Future<Map<int, AnimeRelationNode>> forIds(Iterable<int> malIds) async {
    final List<int> ids = malIds.toList(growable: false);
    if (ids.isEmpty) return const <int, AnimeRelationNode>{};

    final Map<int, CachedRelationNode> nodes = _loadNodes();
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
      await _mergeAndPersist(result, requestedAt);
    }
    return <int, AnimeRelationNode>{...fresh, ...stale, ...fetched};
  }
}
