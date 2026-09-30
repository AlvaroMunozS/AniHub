import 'package:anihub/domain/entities/catalog_anime.dart';
import 'package:anihub/domain/entities/entry.dart';
import 'package:anihub/domain/errors/catalog_exception.dart';
import 'package:anihub/domain/ports/entry_repository.dart';
import 'package:anihub/domain/values/watch_status.dart';
import 'package:anihub/ui/router.dart';
import 'package:anihub/ui/state/library_providers.dart';
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
}
