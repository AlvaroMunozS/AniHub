import 'package:anihub/ui/screens/anime_detail_screen.dart';
import 'package:anihub/ui/screens/library_screen.dart';
import 'package:anihub/ui/screens/more_screen.dart';
import 'package:anihub/ui/screens/search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/sample_data.dart';
import 'support/pump_app.dart';

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
}
