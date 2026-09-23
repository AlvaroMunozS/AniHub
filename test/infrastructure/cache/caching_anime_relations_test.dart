import 'dart:async';

import 'package:anihub/domain/entities/anime_relation_node.dart';
import 'package:anihub/domain/errors/catalog_exception.dart';
import 'package:anihub/domain/ports/anime_relations.dart';
import 'package:anihub/infrastructure/cache/caching_anime_relations.dart';
import 'package:anihub/infrastructure/cache/relations_cache_codec.dart';
import 'package:anihub/infrastructure/cache/snapshot_store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_anime_relations.dart';

class _MemoryStore implements SnapshotStore {
  _MemoryStore([this._value]);

  String? _value;
  int writes = 0;
  bool failOnWrite = false;

  /// When set, every write waits for it, so tests can force overlapping
  /// writes.
  Completer<void>? writeGate;

  Map<int, CachedRelationNode>? get decoded => decodeRelationsCache(_value);

  @override
  String? read() => _value;

  @override
  Future<void> write(String json) async {
    if (writeGate != null) await writeGate!.future;
    if (failOnWrite) throw Exception('disk full');
    writes++;
    _value = json;
  }
}

/// Serves every requested id until [failFromCall], then throws [_offline].
class _FailingLater implements AnimeRelations {
  _FailingLater(this.failFromCall);

  final int failFromCall;
  final List<List<int>> calls = <List<int>>[];

  @override
  Future<Map<int, AnimeRelationNode>> forIds(Iterable<int> malIds) async {
    calls.add(malIds.toList());
    if (calls.length >= failFromCall) throw _offline;
    return <int, AnimeRelationNode>{for (final int id in malIds) id: _node(id)};
  }
}

/// Refuses the first [refusals] calls with [error], then serves every id.
class _RateLimited implements AnimeRelations {
  _RateLimited(this.error, {this.refusals = 1});

  final CatalogRateLimitException error;
  final int refusals;
  int calls = 0;

  @override
  Future<Map<int, AnimeRelationNode>> forIds(Iterable<int> malIds) async {
    if (++calls <= refusals) throw error;
    return <int, AnimeRelationNode>{for (final int id in malIds) id: _node(id)};
  }
}

const CatalogNetworkException _offline = CatalogNetworkException('offline');

final DateTime _savedAt = DateTime.utc(2024);

AnimeRelationNode _node(int id, {String title = 'Cached'}) =>
    AnimeRelationNode(malId: id, title: title);

_MemoryStore _storeWith(Map<int, DateTime> savedAtById) {
  return _MemoryStore(
    encodeRelationsCache(<int, CachedRelationNode>{
      for (final MapEntry<int, DateTime>(:int key, :value)
          in savedAtById.entries)
        key: CachedRelationNode(savedAt: value, node: _node(key)),
    }),
  );
}

void main() {
  final DateTime staleTime = _savedAt.add(const Duration(days: 31));

  test('returns an empty map for no ids without calling the source', () async {
    final FakeAnimeRelations inner = FakeAnimeRelations();
    final CachingAnimeRelations relations = CachingAnimeRelations(
      inner,
      _MemoryStore(),
    );

    expect(await relations.forIds(const <int>[]), isEmpty);
    expect(inner.callCount, 0);
  });

  test('serves fresh nodes without calling the source', () async {
    final FakeAnimeRelations inner = FakeAnimeRelations();
    final CachingAnimeRelations relations = CachingAnimeRelations(
      inner,
      _storeWith(<int, DateTime>{21: _savedAt}),
      now: () => _savedAt.add(const Duration(days: 1)),
    );

    expect(await relations.forIds(<int>[21]), <int, AnimeRelationNode>{
      21: _node(21),
    });
    expect(inner.callCount, 0);
  });

  test('refetches only stale ids', () async {
    final FakeAnimeRelations inner = FakeAnimeRelations(
      graph: <int, AnimeRelationNode>{21: _node(21, title: 'Updated')},
    );
    final CachingAnimeRelations relations = CachingAnimeRelations(
      inner,
      _storeWith(<int, DateTime>{21: _savedAt, 22: staleTime}),
      now: () => staleTime,
    );

    final Map<int, AnimeRelationNode> result = await relations.forIds(<int>[
      21,
      22,
    ]);

    expect(inner.lastRequestedIds, <int>[21]);
    expect(result, <int, AnimeRelationNode>{
      21: _node(21, title: 'Updated'),
      22: _node(22),
    });
  });

  test('stores fetched nodes stamped with the request time', () async {
    final _MemoryStore store = _MemoryStore();
    final CachingAnimeRelations relations = CachingAnimeRelations(
      FakeAnimeRelations(graph: <int, AnimeRelationNode>{21: _node(21)}),
      store,
      now: () => _savedAt,
    );

    await relations.forIds(<int>[21]);

    expect(store.decoded, <int, CachedRelationNode>{
      21: CachedRelationNode(savedAt: _savedAt, node: _node(21)),
    });
  });

  test(
    'keeps serving a stale node that the source no longer returns',
    () async {
      final CachingAnimeRelations relations = CachingAnimeRelations(
        FakeAnimeRelations(graph: const <int, AnimeRelationNode>{}),
        _storeWith(<int, DateTime>{21: _savedAt}),
        now: () => staleTime,
      );

      expect(await relations.forIds(<int>[21]), <int, AnimeRelationNode>{
        21: _node(21),
      });
    },
  );

  test('falls back to stale cached nodes when the source fails', () async {
    final CachingAnimeRelations relations = CachingAnimeRelations(
      FakeAnimeRelations(error: _offline),
      _storeWith(<int, DateTime>{21: _savedAt}),
      now: () => _savedAt.add(const Duration(days: 365)),
    );

    expect(await relations.forIds(<int>[21]), <int, AnimeRelationNode>{
      21: _node(21),
    });
  });

  test('returns the fresh and stale nodes it has when the source fails for '
      'a mix of ids', () async {
    final DateTime requestedAt = _savedAt.add(const Duration(days: 40));
    final CachingAnimeRelations relations = CachingAnimeRelations(
      FakeAnimeRelations(error: _offline),
      _storeWith(<int, DateTime>{21: _savedAt, 22: requestedAt}),
      now: () => requestedAt,
    );

    expect(await relations.forIds(<int>[21, 22, 30]), <int, AnimeRelationNode>{
      21: _node(21),
      22: _node(22),
    });
  });

  test('rethrows when the source fails and none of the ids it was asked for '
      'is cached', () async {
    final DateTime requestedAt = _savedAt.add(const Duration(days: 1));
    final CachingAnimeRelations relations = CachingAnimeRelations(
      FakeAnimeRelations(error: _offline),
      _storeWith(<int, DateTime>{21: _savedAt}),
      now: () => requestedAt,
    );

    await expectLater(relations.forIds(<int>[21, 30]), throwsA(_offline));
  });

  test('prunes nodes older than maxAge on write', () async {
    final _MemoryStore store = _storeWith(<int, DateTime>{
      1: DateTime.utc(2020),
    });
    final CachingAnimeRelations relations = CachingAnimeRelations(
      FakeAnimeRelations(graph: <int, AnimeRelationNode>{2: _node(2)}),
      store,
      now: () => DateTime.utc(2020).add(const Duration(days: 400)),
    );

    await relations.forIds(<int>[2]);

    expect(store.decoded!.keys, <int>[2]);
  });

  test('keeps the results of concurrent calls', () async {
    final _MemoryStore store = _MemoryStore()..writeGate = Completer<void>();
    final CachingAnimeRelations relations = CachingAnimeRelations(
      FakeAnimeRelations(
        graph: <int, AnimeRelationNode>{1: _node(1), 2: _node(2)},
      ),
      store,
    );

    final Future<Map<int, AnimeRelationNode>> first = relations.forIds(<int>[
      1,
    ]);
    final Future<Map<int, AnimeRelationNode>> second = relations.forIds(<int>[
      2,
    ]);
    store.writeGate!.complete();
    await Future.wait(<Future<Map<int, AnimeRelationNode>>>[first, second]);

    expect(store.decoded!.keys, unorderedEquals(<int>[1, 2]));
  });

  test('returns fetched nodes and reports it when the store write '
      'fails', () async {
    final List<String?> logs = <String?>[];
    final DebugPrintCallback originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) => logs.add(message);
    addTearDown(() => debugPrint = originalDebugPrint);
    final _MemoryStore store = _MemoryStore()..failOnWrite = true;
    final CachingAnimeRelations relations = CachingAnimeRelations(
      FakeAnimeRelations(graph: <int, AnimeRelationNode>{21: _node(21)}),
      store,
    );

    expect(await relations.forIds(<int>[21]), <int, AnimeRelationNode>{
      21: _node(21),
    });
    expect(store.writes, 0);
    expect(logs, <Object>[contains('disk full')]);
  });

  test(
    'fetches in chunks and keeps the chunks fetched before a failure',
    () async {
      final _FailingLater inner = _FailingLater(3);
      final _MemoryStore store = _MemoryStore();
      final CachingAnimeRelations relations = CachingAnimeRelations(
        inner,
        store,
        now: () => _savedAt,
        chunkSize: 2,
      );

      final Map<int, AnimeRelationNode> result = await relations.forIds(<int>[
        1,
        2,
        3,
        4,
        5,
      ]);

      expect(inner.calls, <List<int>>[
        <int>[1, 2],
        <int>[3, 4],
        <int>[5],
      ]);
      expect(result.keys, <int>[1, 2, 3, 4]);
      expect(store.decoded!.keys, <int>[1, 2, 3, 4]);
    },
  );

  test('rethrows when the first chunk fails and nothing is cached', () async {
    final CachingAnimeRelations relations = CachingAnimeRelations(
      _FailingLater(1),
      _MemoryStore(),
      now: () => _savedAt,
      chunkSize: 2,
    );

    await expectLater(
      relations.forIds(<int>[1, 2, 3]),
      throwsA(same(_offline)),
    );
  });

  test('retries a rate-limited chunk once after the requested wait', () async {
    final _RateLimited inner = _RateLimited(
      const CatalogRateLimitException(retryAfter: Duration(seconds: 3)),
    );
    final List<Duration> waits = <Duration>[];
    final CachingAnimeRelations relations = CachingAnimeRelations(
      inner,
      _MemoryStore(),
      now: () => _savedAt,
      wait: (Duration d) async => waits.add(d),
    );

    final Map<int, AnimeRelationNode> result = await relations.forIds(<int>[1]);

    expect(result.keys, <int>[1]);
    expect(inner.calls, 2);
    expect(waits, <Duration>[const Duration(seconds: 3)]);
  });

  test('gives up on a rate limit that asks for a longer wait than '
      'maxRetryWait, or refuses twice', () async {
    for (final _RateLimited inner in <_RateLimited>[
      _RateLimited(
        const CatalogRateLimitException(retryAfter: Duration(minutes: 5)),
      ),
      _RateLimited(const CatalogRateLimitException(), refusals: 2),
    ]) {
      final CachingAnimeRelations relations = CachingAnimeRelations(
        inner,
        _MemoryStore(),
        now: () => _savedAt,
        wait: (Duration _) async {},
      );

      await expectLater(relations.forIds(<int>[1]), throwsA(same(inner.error)));
    }
  });
}
