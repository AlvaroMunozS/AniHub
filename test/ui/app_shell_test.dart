import 'package:anihub/domain/entities/anime_relation.dart';
import 'package:anihub/domain/entities/anime_relation_node.dart';
import 'package:anihub/domain/values/relation_kind.dart';
import 'package:anihub/ui/screens/anime_detail_screen.dart';
import 'package:anihub/ui/screens/library_screen.dart';
import 'package:anihub/ui/screens/more_screen.dart';
import 'package:anihub/ui/screens/search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_anime_relations.dart';
import '../support/sample_data.dart';
import 'support/pump_app.dart';

/// Past the search debounce.
const Duration _debounce = Duration(milliseconds: 400);

/// Frieren leads to Steins;Gate 0, which leads to Cowboy Bebop.
FakeAnimeRelations _sequelChain() => FakeAnimeRelations(
  graph: <int, AnimeRelationNode>{
    52991: const AnimeRelationNode(
      malId: 52991,
      title: 'Sousou no Frieren',
      relations: <AnimeRelation>[
        AnimeRelation(
          malId: 30484,
          kind: RelationKind.sequel,
          title: 'Steins;Gate 0',
          seasonYear: 2018,
        ),
      ],
    ),
    30484: const AnimeRelationNode(
      malId: 30484,
      title: 'Steins;Gate 0',
      relations: <AnimeRelation>[
        AnimeRelation(
          malId: 1,
          kind: RelationKind.sequel,
          title: 'Cowboy Bebop',
          seasonYear: 1998,
        ),
      ],
    ),
  },
);

Future<void> _openRelation(WidgetTester tester, String title) async {
  await tester.ensureVisible(find.text(title));
  await tester.pumpAndSettle();
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
}

Future<void> _tapDestination(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('navigates between three destinations', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, repo: inMemoryLibrary(sampleEntries()));

    expect(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byType(NavigationDestination),
      ),
      findsNWidgets(3),
    );

    await _tapDestination(tester, 'Navegar');
    expect(find.byType(SearchScreen), findsOneWidget);

    await _tapDestination(tester, 'Más');
    expect(find.byType(MoreScreen), findsOneWidget);
  });

  testWidgets('returns to the last library tab from another destination', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, repo: inMemoryLibrary(sampleEntries()));

    await tester.tap(find.text('Completado'));
    await tester.pumpAndSettle();
    await _tapDestination(tester, 'Navegar');
    await _tapDestination(tester, 'Biblioteca');

    final TabBar tabBar = tester.widget<TabBar>(find.byType(TabBar));
    expect(tabBar.controller!.index, 2);
  });

  testWidgets('hides the navigation bar while a poster detail is open', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, repo: inMemoryLibrary(sampleEntries()));
    expect(find.byType(NavigationBar), findsOneWidget);

    // Frieren is planned in the sample data.
    await tester.tap(find.text('Pendiente'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sousou no Frieren'));
    await tester.pumpAndSettle();

    expect(find.byType(AnimeDetailScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();

    expect(find.byType(LibraryScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('returns to the library after following related anime', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      repo: inMemoryLibrary(sampleEntries()),
      relations: _sequelChain(),
    );

    await tester.tap(find.text('Pendiente'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sousou no Frieren'));
    await tester.pumpAndSettle();

    await _openRelation(tester, 'Steins;Gate 0');
    expect(find.byType(NavigationBar), findsNothing);
    await _openRelation(tester, 'Cowboy Bebop');
    expect(find.byType(NavigationBar), findsNothing);

    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();

    expect(find.byType(LibraryScreen), findsOneWidget);
    expect(find.byType(AnimeDetailScreen, skipOffstage: false), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
    final TabBar tabBar = tester.widget<TabBar>(find.byType(TabBar));
    expect(tabBar.controller!.index, 1);
  });

  testWidgets(
    'returns to search with the system back after following related anime',
    (WidgetTester tester) async {
      await pumpApp(
        tester,
        repo: inMemoryLibrary(sampleEntries()),
        relations: _sequelChain(),
      );

      await _tapDestination(tester, 'Navegar');
      await tester.enterText(find.byType(TextField), 'Frieren');
      await tester.pump(_debounce);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sousou no Frieren'));
      await tester.pumpAndSettle();

      await _openRelation(tester, 'Steins;Gate 0');
      expect(find.byType(NavigationBar), findsNothing);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(SearchScreen), findsOneWidget);
      expect(find.byType(AnimeDetailScreen, skipOffstage: false), findsNothing);
      expect(find.widgetWithText(TextField, 'Frieren'), findsOneWidget);
      expect(find.text('Sousou no Frieren'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
    },
  );
}
