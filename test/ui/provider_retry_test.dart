import 'package:anihub/domain/entities/anime_relation_node.dart';
import 'package:anihub/domain/entities/catalog_anime.dart';
import 'package:anihub/domain/entities/entry.dart';
import 'package:anihub/domain/errors/catalog_exception.dart';
import 'package:anihub/domain/ports/anime_relations.dart';
import 'package:anihub/domain/ports/entry_repository.dart';
import 'package:anihub/domain/values/watch_status.dart';
import 'package:anihub/ui/providers.dart';
import 'package:anihub/ui/router.dart';
import 'package:anihub/ui/state/anime_detail_providers.dart';
import 'package:anihub/ui/state/library_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_anime_catalog.dart';
import '../support/fake_anime_relations.dart';
import 'support/pump_app.dart';

class _CountingCatalog extends FakeAnimeCatalog {
  int byIdCalls = 0;

  @override
  Future<CatalogAnime> byId(int malId) {
    byIdCalls++;
    return super.byId(malId);
  }
}

/// Relations that fail while [failing] is set.
class _FlakyRelations implements AnimeRelations {
  bool failing = true;
  int calls = 0;

  @override
  Future<Map<int, AnimeRelationNode>> forIds(Iterable<int> malIds) async {
    calls++;
    if (failing) throw const CatalogNetworkException('offline');
    return <int, AnimeRelationNode>{
      for (final int id in malIds)
        id: AnimeRelationNode(malId: id, title: 'Anime $id'),
    };
  }
}

class _FailingRepository implements EntryRepository {
  int watchCalls = 0;

  @override
  Future<List<Entry>> findAll() async => <Entry>[];

  @override
  Future<Entry> save(Entry entry) async => entry;

  @override
  Future<void> delete(String id) async {}

  @override
  Future<void> upsertAll(List<Entry> entries) async {}

  @override
  Stream<List<Entry>> watchAll() async* {
    watchCalls++;
    throw Exception('read failed');
  }
}

/// Longer than the ten retries Riverpod makes by default, about 38 seconds in
/// all.
const Duration _pastDefaultRetries = Duration(seconds: 40);

void main() {
  testWidgets('asks for an unknown anime once', (WidgetTester tester) async {
    final _CountingCatalog catalog = _CountingCatalog();

    await pumpApp(
      tester,
      catalog: catalog,
      initialLocation: RoutePaths.animeDetail(999999),
    );
    await tester.pump(_pastDefaultRetries);

    expect(catalog.byIdCalls, 1);
  });

  testWidgets('reads a failing library once', (WidgetTester tester) async {
    final _FailingRepository repo = _FailingRepository();

    await pumpApp(tester, repo: repo);
    await tester.pump(_pastDefaultRetries);

    expect(tester.takeException(), isException);
    expect(repo.watchCalls, 1);
    expect(find.widgetWithText(OutlinedButton, 'Reintentar'), findsOneWidget);
  });

  testWidgets('follows its own retry schedule when the relations fail', (
    WidgetTester tester,
  ) async {
    final FakeAnimeRelations relations = FakeAnimeRelations(
      error: const CatalogNetworkException('offline'),
    );

    await pumpApp(
      tester,
      repo: inMemoryLibrary(<Entry>[
        Entry(
          id: 'id-1',
          malId: 1,
          title: 'Cowboy Bebop',
          status: WatchStatus.watching,
          updatedAt: DateTime(2024),
        ),
      ]),
      relations: relations,
    );
    await tester.pump(_pastDefaultRetries);

    expect(relations.callCount, 1);

    await tester.pump(LibraryRelations.retryDelays[0]);
    await tester.pumpAndSettle();

    expect(relations.callCount, 2);
  });

  test('asks for the relations of an anime again after a failure', () async {
    final _FlakyRelations relations = _FlakyRelations();
    final ProviderContainer container = ProviderContainer(
      retry: noProviderRetry,
      overrides: <Override>[
        animeRelationsProvider.overrideWithValue(relations),
      ],
    );
    addTearDown(container.dispose);

    final ProviderSubscription<AsyncValue<AnimeRelationNode?>> first = container
        .listen(animeRelationsByIdProvider(1), (_, _) {});
    await expectLater(
      container.read(animeRelationsByIdProvider(1).future),
      throwsA(isA<CatalogNetworkException>()),
    );
    first.close();
    await Future<void>.delayed(Duration.zero);

    relations.failing = false;
    final AnimeRelationNode? node = await container.read(
      animeRelationsByIdProvider(1).future,
    );

    expect(node?.malId, 1);
    expect(relations.calls, 2);
  });

  test('asks for an anime again after a failure', () async {
    final _CountingCatalog catalog = _CountingCatalog();
    final ProviderContainer container = ProviderContainer(
      retry: noProviderRetry,
      overrides: <Override>[animeCatalogProvider.overrideWithValue(catalog)],
    );
    addTearDown(container.dispose);

    final ProviderSubscription<AsyncValue<CatalogAnime>> first = container
        .listen(animeByIdProvider(999999), (_, _) {});
    await expectLater(
      container.read(animeByIdProvider(999999).future),
      throwsA(isA<CatalogNotFoundException>()),
    );
    first.close();
    await Future<void>.delayed(Duration.zero);

    container.listen(animeByIdProvider(999999), (_, _) {});
    await expectLater(
      container.read(animeByIdProvider(999999).future),
      throwsA(isA<CatalogNotFoundException>()),
    );

    expect(catalog.byIdCalls, 2);
  });
}
