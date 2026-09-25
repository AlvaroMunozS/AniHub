import 'dart:async';

import 'package:anihub/application/usecases/usecases.dart';
import 'package:anihub/domain/entities/anime_relation.dart';
import 'package:anihub/domain/entities/anime_relation_node.dart';
import 'package:anihub/domain/entities/entry.dart';
import 'package:anihub/domain/errors/catalog_exception.dart';
import 'package:anihub/domain/ports/anime_relations.dart';
import 'package:anihub/domain/ports/entry_repository.dart';
import 'package:anihub/domain/values/relation_kind.dart';
import 'package:anihub/domain/values/release_date.dart';
import 'package:anihub/domain/values/watch_status.dart';
import 'package:anihub/ui/providers.dart';
import 'package:anihub/ui/screens/anime_detail_screen.dart';
import 'package:anihub/ui/state/library_providers.dart';
import 'package:anihub/ui/widgets/entry_card.dart';
import 'package:anihub/ui/widgets/group_card.dart';
import 'package:anihub/ui/widgets/stacked_covers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_anime_relations.dart';
import '../support/in_memory_entry_repository.dart';
import 'support/pump_app.dart';

/// Two Steins;Gate seasons linked as sequel and prequel. Both exist in
/// `sampleCatalog`, so their detail screens load.
Map<int, AnimeRelationNode> _graph() {
  const AnimeRelationNode seasonOne = AnimeRelationNode(
    malId: 9253,
    title: 'Steins;Gate',
    seasonYear: 2011,
    startDate: ReleaseDate(year: 2011, month: 4, day: 6),
    relations: <AnimeRelation>[
      AnimeRelation(
        malId: 30484,
        kind: RelationKind.sequel,
        title: 'Steins;Gate 0',
        seasonYear: 2015,
      ),
    ],
  );
  const AnimeRelationNode seasonZero = AnimeRelationNode(
    malId: 30484,
    title: 'Steins;Gate 0',
    seasonYear: 2015,
    startDate: ReleaseDate(year: 2015, month: 4, day: 11),
    relations: <AnimeRelation>[
      AnimeRelation(
        malId: 9253,
        kind: RelationKind.prequel,
        title: 'Steins;Gate',
        seasonYear: 2011,
      ),
    ],
  );
  return <int, AnimeRelationNode>{9253: seasonOne, 30484: seasonZero};
}

/// An entry the relation source does not know.
final Entry _unknown = Entry(
  malId: 404,
  title: 'Unknown',
  status: WatchStatus.planned,
  updatedAt: DateTime.utc(2024),
);

List<Entry> _twoSeasons() {
  final DateTime now = DateTime.now();
  return <Entry>[
    Entry(
      malId: 30484,
      title: 'Steins;Gate 0',
      status: WatchStatus.watching,
      updatedAt: now,
    ),
    Entry(
      malId: 9253,
      title: 'Steins;Gate',
      status: WatchStatus.watching,
      updatedAt: now.subtract(const Duration(minutes: 1)),
    ),
  ];
}

/// Four seasons chained by sequel and prequel edges.
Map<int, AnimeRelationNode> _fourSeasons() {
  AnimeRelationNode season(int malId) {
    return AnimeRelationNode(
      malId: malId,
      title: 'Season $malId',
      seasonYear: 2000 + malId,
      relations: <AnimeRelation>[
        if (malId > 1)
          AnimeRelation(
            malId: malId - 1,
            kind: RelationKind.prequel,
            title: 'Season ${malId - 1}',
          ),
        if (malId < 4)
          AnimeRelation(
            malId: malId + 1,
            kind: RelationKind.sequel,
            title: 'Season ${malId + 1}',
          ),
      ],
    );
  }

  return <int, AnimeRelationNode>{
    for (int id = 1; id <= 4; id++) id: season(id),
  };
}

/// Seasons 1 and 4 being watched, without seasons 2 and 3.
List<Entry> _firstAndLastSeasons() {
  final DateTime now = DateTime.now();
  return <Entry>[
    Entry(
      malId: 4,
      title: 'Season 4',
      status: WatchStatus.watching,
      updatedAt: now,
    ),
    Entry(
      malId: 1,
      title: 'Season 1',
      status: WatchStatus.watching,
      updatedAt: now.subtract(const Duration(minutes: 1)),
    ),
  ];
}

/// Serves [graph], holding the lookups of ids outside [library] until
/// [release], failing the first [failures] of them, and throwing [bug] from
/// them when set.
class _Chains implements AnimeRelations {
  _Chains(this.graph, this.library, {this.failures = 0, this.bug});

  final Map<int, AnimeRelationNode> graph;
  final Set<int> library;
  int failures;
  final Object? bug;
  Completer<void> release = Completer<void>()..complete();
  int calls = 0;

  @override
  Future<Map<int, AnimeRelationNode>> forIds(Iterable<int> malIds) async {
    calls++;
    final List<int> ids = List<int>.of(malIds);
    if (!ids.every(library.contains)) {
      await release.future;
      if (bug != null) throw bug!;
      if (failures > 0) {
        failures--;
        throw const CatalogNetworkException('down');
      }
    }
    return <int, AnimeRelationNode>{
      for (final int id in ids)
        if (graph[id] != null) id: graph[id]!,
    };
  }
}

Future<ProviderContainer> _pumpContainer(
  WidgetTester tester,
  EntryRepository repo,
  AnimeRelations relations,
) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      sharedPreferencesProvider.overrideWithValue(
        await SharedPreferences.getInstance(),
      ),
      entryRepositoryProvider.overrideWithValue(repo),
      animeRelationsProvider.overrideWithValue(relations),
    ],
  );
  addTearDown(container.dispose);
  container.listen(libraryGroupsProvider(WatchStatus.watching), (_, _) {});
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const SizedBox()),
  );
  await tester.pumpAndSettle();
  return container;
}

List<LibraryGroupItem> _groups(ProviderContainer container) => container
    .read(libraryGroupsProvider(WatchStatus.watching))
    .whereType<LibraryGroupItem>()
    .toList();

/// Returns [graph] minus the ids in [missing], which shrinks by one id per
/// call, like a source that recovers bit by bit.
class _Recovering implements AnimeRelations {
  _Recovering(this.graph, this.missing);

  final Map<int, AnimeRelationNode> graph;
  final List<int> missing;
  int calls = 0;

  @override
  Future<Map<int, AnimeRelationNode>> forIds(Iterable<int> malIds) async {
    calls++;
    final Map<int, AnimeRelationNode> result = <int, AnimeRelationNode>{
      for (final int id in malIds)
        if (graph[id] != null && !missing.contains(id)) id: graph[id]!,
    };
    if (missing.isNotEmpty) missing.removeAt(0);
    return result;
  }
}

void main() {
  testWidgets('expands and collapses a group whose members open their detail', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      repo: inMemoryLibrary(_twoSeasons()),
      relations: FakeAnimeRelations(graph: _graph()),
    );

    // Collapsed: a single cell labeled with the oldest member's title.
    expect(find.byType(GroupCard), findsOneWidget);
    expect(find.byType(StackedCovers), findsOneWidget);
    expect(find.byType(EntryCard), findsNothing);
    expect(find.text('Steins;Gate'), findsOneWidget);
    expect(find.text('Steins;Gate 0'), findsNothing);

    await tester.tap(find.byType(GroupCard));
    await tester.pumpAndSettle();

    expect(find.byType(GroupCard), findsOneWidget);
    expect(find.byType(EntryCard), findsNWidgets(2));
    // Once for the group label and once for the oldest member.
    expect(find.text('Steins;Gate'), findsNWidgets(2));
    expect(find.text('Steins;Gate 0'), findsOneWidget);

    await tester.tap(find.text('Steins;Gate 0'));
    await tester.pumpAndSettle();
    expect(find.byType(AnimeDetailScreen), findsOneWidget);

    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(GroupCard));
    await tester.pumpAndSettle();

    expect(find.byType(EntryCard), findsNothing);
    expect(find.byType(GroupCard), findsOneWidget);
  });

  testWidgets('shows entries ungrouped when the relation graph fails', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      repo: inMemoryLibrary(_twoSeasons()),
      relations: FakeAnimeRelations(
        error: const CatalogNetworkException('down'),
      ),
    );

    expect(find.byType(StackedCovers), findsNothing);
    expect(find.byType(GroupCard), findsNothing);
    expect(find.byType(EntryCard), findsNWidgets(2));
  });

  testWidgets('keeps a group expanded when the library stream re-emits', (
    WidgetTester tester,
  ) async {
    final InMemoryEntryRepository repo = inMemoryLibrary(_twoSeasons());
    await pumpApp(
      tester,
      repo: repo,
      relations: FakeAnimeRelations(graph: _graph()),
    );

    await tester.tap(find.byType(GroupCard));
    await tester.pumpAndSettle();
    expect(find.byType(EntryCard), findsNWidgets(2));

    final Entry current = (await repo.findAll()).firstWhere(
      (Entry e) => e.malId == 9253,
    );
    await repo.save(current);
    await tester.pumpAndSettle();

    expect(find.byType(GroupCard), findsOneWidget);
    expect(find.byType(EntryCard), findsNWidgets(2));
  });

  testWidgets('does not refetch relations when an entry is saved again', (
    WidgetTester tester,
  ) async {
    final Entry standalone = Entry(
      malId: 1,
      title: 'Cowboy Bebop',
      status: WatchStatus.watching,
      updatedAt: DateTime.now().subtract(const Duration(minutes: 5)),
    );
    final InMemoryEntryRepository repo = inMemoryLibrary(<Entry>[
      ..._twoSeasons(),
      standalone,
    ]);
    final FakeAnimeRelations relations = FakeAnimeRelations(
      graph: <int, AnimeRelationNode>{
        ..._graph(),
        1: const AnimeRelationNode(malId: 1, title: 'Cowboy Bebop'),
      },
    );
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        sharedPreferencesProvider.overrideWithValue(
          await SharedPreferences.getInstance(),
        ),
        entryRepositoryProvider.overrideWithValue(repo),
        animeRelationsProvider.overrideWithValue(relations),
      ],
    );
    addTearDown(container.dispose);

    // Keeps the provider alive so it subscribes to the library stream.
    container.listen(libraryGroupsProvider(WatchStatus.watching), (_, _) {});
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const SizedBox()),
    );
    await tester.pumpAndSettle();

    List<LibraryGroupItem> groups() => container
        .read(libraryGroupsProvider(WatchStatus.watching))
        .whereType<LibraryGroupItem>()
        .toList();

    expect(groups(), hasLength(1));
    final int callsBefore = relations.callCount;

    final Entry current = (await repo.findAll()).firstWhere(
      (Entry e) => e.malId == standalone.malId,
    );
    await repo.save(current);
    await tester.pump();

    expect(groups(), hasLength(1));
    expect(relations.callCount, callsBefore);
  });

  testWidgets('fetches the relations again while some ids are missing, up to '
      'the retry limit', (WidgetTester tester) async {
    final _Recovering relations = _Recovering(_graph(), <int>[9253, 9253]);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        sharedPreferencesProvider.overrideWithValue(
          await SharedPreferences.getInstance(),
        ),
        entryRepositoryProvider.overrideWithValue(
          inMemoryLibrary(<Entry>[..._twoSeasons(), _unknown]),
        ),
        animeRelationsProvider.overrideWithValue(relations),
      ],
    );
    addTearDown(container.dispose);
    container.listen(libraryRelationsProvider, (_, _) {});
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const SizedBox()),
    );
    await tester.pumpAndSettle();

    Iterable<int> fetched() =>
        container.read(libraryRelationsProvider).value!.keys;

    expect(fetched(), isNot(contains(9253)));
    await tester.pump(LibraryRelations.retryDelays[0]);
    await tester.pumpAndSettle();
    expect(fetched(), isNot(contains(9253)));
    await tester.pump(LibraryRelations.retryDelays[1]);
    await tester.pumpAndSettle();
    expect(fetched(), containsAll(<int>[9253, 30484]));

    // The unknown id stays missing, so the last retry is the final call.
    await tester.pump(LibraryRelations.retryDelays[2]);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(hours: 1));
    expect(relations.calls, 1 + LibraryRelations.retryDelays.length);
  });

  testWidgets('groups seasons linked only through anime missing from the '
      'library once the chain is fetched', (WidgetTester tester) async {
    final _Chains relations = _Chains(_fourSeasons(), <int>{1, 4})
      ..release = Completer<void>();
    final ProviderContainer container = await _pumpContainer(
      tester,
      inMemoryLibrary(_firstAndLastSeasons()),
      relations,
    );

    expect(_groups(container), isEmpty);
    expect(container.read(libraryRelationsProvider).value!.keys, <int>[1, 4]);

    relations.release.complete();
    await tester.pumpAndSettle();

    expect(_groups(container), hasLength(1));
    expect(_groups(container).single.members.map((Entry e) => e.malId), <int>[
      1,
      4,
    ]);
  });

  testWidgets('fetches the chain again after it fails', (
    WidgetTester tester,
  ) async {
    final _Chains relations = _Chains(_fourSeasons(), <int>{1, 4}, failures: 1);
    final ProviderContainer container = await _pumpContainer(
      tester,
      inMemoryLibrary(_firstAndLastSeasons()),
      relations,
    );

    expect(_groups(container), isEmpty);

    await tester.pump(LibraryRelations.retryDelays[0]);
    await tester.pumpAndSettle();

    expect(_groups(container), hasLength(1));
  });

  testWidgets('keeps seasons linked by a chain grouped while the library '
      'changes', (WidgetTester tester) async {
    final _Chains relations = _Chains(
      <int, AnimeRelationNode>{
        ..._fourSeasons(),
        100: const AnimeRelationNode(malId: 100, title: 'Standalone'),
      },
      <int>{1, 4, 100},
    );
    final EntryRepository repo = inMemoryLibrary(_firstAndLastSeasons());
    final ProviderContainer container = await _pumpContainer(
      tester,
      repo,
      relations,
    );
    expect(_groups(container), hasLength(1));

    relations.release = Completer<void>();
    await repo.save(
      Entry(
        malId: 100,
        title: 'Standalone',
        status: WatchStatus.watching,
        updatedAt: DateTime.now(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(_groups(container), hasLength(1));

    relations.release.complete();
    await tester.pumpAndSettle();

    expect(_groups(container), hasLength(1));
  });

  testWidgets('reports an unexpected chain failure and keeps the direct '
      'graph without retrying', (WidgetTester tester) async {
    final _Chains relations = _Chains(_fourSeasons(), <int>{
      1,
      4,
    }, bug: StateError('bug'));
    final ProviderContainer container = await _pumpContainer(
      tester,
      inMemoryLibrary(_firstAndLastSeasons()),
      relations,
    );

    expect(tester.takeException(), isStateError);
    expect(container.read(libraryRelationsProvider).value!.keys, <int>[1, 4]);
    final int calls = relations.calls;

    await tester.pump(LibraryRelations.retryDelays[0]);
    await tester.pumpAndSettle();

    expect(relations.calls, calls);
  });
}
