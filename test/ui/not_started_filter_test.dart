import 'dart:async';

import 'package:anihub/application/usecases/usecases.dart';
import 'package:anihub/domain/entities/anime_relation.dart';
import 'package:anihub/domain/entities/anime_relation_node.dart';
import 'package:anihub/domain/entities/entry.dart';
import 'package:anihub/domain/values/relation_kind.dart';
import 'package:anihub/domain/values/watch_status.dart';
import 'package:anihub/ui/providers.dart';
import 'package:anihub/ui/router.dart';
import 'package:anihub/ui/state/library_providers.dart';
import 'package:anihub/ui/widgets/entry_card.dart';
import 'package:anihub/ui/widgets/group_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_anime_relations.dart';
import 'support/controllable_repository.dart';
import 'support/pump_app.dart';

/// Seasons 1, 2 and 3 of a franchise linked by sequel edges, plus a
/// standalone anime.
Map<int, AnimeRelationNode> _graph() {
  AnimeRelationNode season(int malId, List<AnimeRelation> relations) {
    return AnimeRelationNode(
      malId: malId,
      title: 'Season $malId',
      seasonYear: 2000 + malId,
      relations: relations,
    );
  }

  return <int, AnimeRelationNode>{
    1: season(1, const <AnimeRelation>[
      AnimeRelation(malId: 2, kind: RelationKind.sequel, title: 'Season 2'),
    ]),
    2: season(2, const <AnimeRelation>[
      AnimeRelation(malId: 1, kind: RelationKind.prequel, title: 'Season 1'),
      AnimeRelation(malId: 3, kind: RelationKind.sequel, title: 'Season 3'),
    ]),
    3: season(3, const <AnimeRelation>[
      AnimeRelation(malId: 2, kind: RelationKind.prequel, title: 'Season 2'),
    ]),
    100: const AnimeRelationNode(malId: 100, title: 'Standalone'),
  };
}

Entry _entry(int malId, String title, WatchStatus status, {int age = 0}) {
  return Entry(
    id: 'e$malId',
    malId: malId,
    title: title,
    status: status,
    updatedAt: DateTime(2024).subtract(Duration(minutes: age)),
  );
}

/// Season 1 completed, seasons 2 and 3 planned, and a planned standalone.
List<Entry> _library() => <Entry>[
  _entry(1, 'Season 1', WatchStatus.completed),
  _entry(2, 'Season 2', WatchStatus.planned, age: 1),
  _entry(3, 'Season 3', WatchStatus.planned, age: 2),
  _entry(100, 'Standalone', WatchStatus.planned, age: 3),
];

final String _plannedTab = RoutePaths.libraryFor(WatchStatus.planned);

Future<void> _pumpPlanned(WidgetTester tester, List<Entry> library) async {
  final ControllableRepository repo = ControllableRepository(library);
  addTearDown(repo.dispose);
  await pumpApp(
    tester,
    repo: repo,
    relations: FakeAnimeRelations(graph: _graph()),
    initialLocation: _plannedTab,
  );
}

/// Taps the not-started filter [times] times from the options sheet, then
/// dismisses the sheet by tapping outside it.
Future<void> _cycleNotStarted(WidgetTester tester, {int times = 1}) async {
  await tester.tap(find.byIcon(Icons.filter_list));
  await tester.pumpAndSettle();
  for (int i = 0; i < times; i++) {
    await tester.tap(find.text('Sin empezar'));
    await tester.pumpAndSettle();
  }
  await tester.tapAt(const Offset(20, 20));
  await tester.pumpAndSettle();
}

Iterable<int> _malIds(List<LibraryItem> items) {
  return items
      .expand(
        (LibraryItem item) => switch (item) {
          LibraryEntryItem(:final Entry entry) => <Entry>[entry],
          LibraryGroupItem(:final List<Entry> members) => members,
        },
      )
      .map((Entry e) => e.malId);
}

void main() {
  testWidgets('shows only anime of series not started when set to only', (
    WidgetTester tester,
  ) async {
    await _pumpPlanned(tester, _library());
    expect(find.byType(GroupCard), findsOneWidget);

    await _cycleNotStarted(tester);

    expect(find.text('Standalone'), findsOneWidget);
    expect(find.byType(GroupCard), findsNothing);
    expect(find.byTooltip('Filtrar y ordenar (filtro activo)'), findsOneWidget);
  });

  testWidgets('keeps the next seasons of started series as one group when '
      'set to exclude', (WidgetTester tester) async {
    await _pumpPlanned(tester, _library());

    await _cycleNotStarted(tester, times: 2);

    expect(find.text('Standalone'), findsNothing);
    expect(find.byType(GroupCard), findsOneWidget);
    expect(find.byType(EntryCard), findsNothing);
  });

  testWidgets('keeps a franchise with only planned seasons as one group when '
      'set to only', (WidgetTester tester) async {
    await _pumpPlanned(tester, <Entry>[
      _entry(2, 'Season 2', WatchStatus.planned),
      _entry(3, 'Season 3', WatchStatus.planned, age: 1),
      _entry(100, 'Standalone', WatchStatus.completed, age: 2),
    ]);

    await _cycleNotStarted(tester);

    expect(find.byType(GroupCard), findsOneWidget);
    expect(find.byType(EntryCard), findsNothing);
  });

  testWidgets('shows everything again on the third tap', (
    WidgetTester tester,
  ) async {
    await _pumpPlanned(tester, _library());

    await _cycleNotStarted(tester, times: 3);

    expect(find.text('Standalone'), findsOneWidget);
    expect(find.byType(GroupCard), findsOneWidget);
    expect(find.byTooltip('Filtrar y ordenar'), findsOneWidget);
  });

  testWidgets('does not narrow the completed tab', (WidgetTester tester) async {
    await _pumpPlanned(tester, _library());
    await _cycleNotStarted(tester);

    await tester.tap(find.text('Completado'));
    await tester.pumpAndSettle();

    expect(find.text('Season 1'), findsOneWidget);
    expect(find.byTooltip('Filtrar y ordenar'), findsOneWidget);
  });

  testWidgets('offers the not-started filter only on the planned tab', (
    WidgetTester tester,
  ) async {
    await _pumpPlanned(tester, _library());
    await tester.tap(find.byIcon(Icons.filter_list));
    await tester.pumpAndSettle();
    expect(find.text('Sin empezar'), findsOneWidget);
    expect(find.text('Favoritos'), findsNothing);
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Viendo'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.filter_list));
    await tester.pumpAndSettle();

    expect(find.text('Ordenar'), findsOneWidget);
    expect(find.text('Sin empezar'), findsNothing);
  });

  testWidgets('shows an empty state when nothing matches the filters', (
    WidgetTester tester,
  ) async {
    await _pumpPlanned(tester, <Entry>[
      _entry(100, 'Standalone', WatchStatus.planned),
    ]);

    await _cycleNotStarted(tester, times: 2);

    expect(
      find.text('Nada coincide con los filtros en Pendiente.'),
      findsOneWidget,
    );
  });

  testWidgets('announces the mode of the filter', (WidgetTester tester) async {
    await _pumpPlanned(tester, _library());
    await tester.tap(find.byIcon(Icons.filter_list));
    await tester.pumpAndSettle();

    final Finder tile = find.bySemanticsLabel('Sin empezar');
    expect(tester.getSemantics(tile).value, 'Sin filtrar');
    await tester.tap(find.text('Sin empezar'));
    await tester.pumpAndSettle();
    expect(tester.getSemantics(tile).value, 'Solo estos');
    await tester.tap(find.text('Sin empezar'));
    await tester.pumpAndSettle();
    expect(tester.getSemantics(tile).value, 'Ocultando estos');
  });

  testWidgets('completing a season moves the next one out of the filter '
      'before the write completes', (WidgetTester tester) async {
    final ControllableRepository repo = ControllableRepository(<Entry>[
      _entry(1, 'Season 1', WatchStatus.planned),
      _entry(2, 'Season 2', WatchStatus.planned, age: 1),
    ])..saveGate = Completer<void>();
    addTearDown(repo.dispose);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        sharedPreferencesProvider.overrideWithValue(
          await SharedPreferences.getInstance(),
        ),
        entryRepositoryProvider.overrideWithValue(repo),
        animeRelationsProvider.overrideWithValue(
          FakeAnimeRelations(graph: _graph()),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(libraryGroupsProvider(WatchStatus.planned), (_, _) {});
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const SizedBox()),
    );
    await tester.pumpAndSettle();
    container.read(libraryFilterProvider.notifier).cycleNotStarted();

    List<LibraryItem> planned() =>
        container.read(libraryGroupsProvider(WatchStatus.planned));

    expect(_malIds(planned()), unorderedEquals(<int>[1, 2]));

    final Entry seasonOne = (await repo.findAll()).first;
    unawaited(
      container
          .read(pendingEntryChangesProvider.notifier)
          .changeStatus(seasonOne, WatchStatus.completed),
    );
    await tester.pump();

    expect(planned(), isEmpty);

    repo.saveGate!.complete();
    await tester.pumpAndSettle();
  });
}
