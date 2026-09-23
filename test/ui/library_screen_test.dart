import 'package:anihub/domain/entities/entry.dart';
import 'package:anihub/domain/values/watch_status.dart';
import 'package:anihub/ui/router.dart';
import 'package:anihub/ui/widgets/entry_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/sample_data.dart';
import 'support/pump_app.dart';

Future<void> _pumpSampleLibrary(WidgetTester tester) {
  return pumpApp(tester, repo: inMemoryLibrary(sampleEntries()));
}

String _query(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).controller!.text;

void main() {
  testWidgets('shows the entries of the tapped tab', (
    WidgetTester tester,
  ) async {
    await _pumpSampleLibrary(tester);

    expect(find.text('One Piece'), findsOneWidget);
    expect(find.text('Fullmetal Alchemist: Brotherhood'), findsOneWidget);
    expect(find.text('Sousou no Frieren'), findsNothing);

    await tester.tap(find.text('Pendiente'));
    await tester.pumpAndSettle();

    expect(find.text('Sousou no Frieren'), findsOneWidget);
    expect(find.text('One Piece'), findsNothing);
  });

  testWidgets('filters the library by title while typing', (
    WidgetTester tester,
  ) async {
    await _pumpSampleLibrary(tester);

    await tester.enterText(find.byType(TextField), 'One');
    await tester.pumpAndSettle();

    expect(find.text('One Piece'), findsOneWidget);
    expect(find.text('Fullmetal Alchemist: Brotherhood'), findsNothing);
  });

  testWidgets(
    'keeps the query across tabs and clears it when leaving the library',
    (WidgetTester tester) async {
      await _pumpSampleLibrary(tester);

      await tester.enterText(find.byType(TextField), 'Frieren');
      await tester.pumpAndSettle();
      expect(find.text('Sin resultados'), findsOneWidget);

      await tester.tap(find.text('Pendiente'));
      await tester.pumpAndSettle();
      expect(find.text('Sousou no Frieren'), findsOneWidget);
      expect(_query(tester), 'Frieren');

      await tester.tap(find.text('Navegar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Biblioteca'));
      await tester.pumpAndSettle();

      expect(_query(tester), '');
      expect(find.text('Sousou no Frieren'), findsOneWidget);
    },
  );

  testWidgets('names the active tab when nothing matches', (
    WidgetTester tester,
  ) async {
    await _pumpSampleLibrary(tester);

    await tester.enterText(find.byType(TextField), 'no such anime');
    await tester.pumpAndSettle();

    expect(find.text('Sin resultados'), findsOneWidget);
    expect(
      find.text('No hay nada para «no such anime» en Viendo.'),
      findsOneWidget,
    );
  });

  testWidgets('explains an empty tab', (WidgetTester tester) async {
    await pumpApp(
      tester,
      repo: inMemoryLibrary(<Entry>[
        Entry(
          malId: 5114,
          title: 'Fullmetal Alchemist: Brotherhood',
          status: WatchStatus.watching,
          updatedAt: DateTime(2024),
        ),
      ]),
      initialLocation: RoutePaths.libraryFor(WatchStatus.completed),
    );

    expect(find.text('Aún no has completado nada'), findsOneWidget);
    expect(find.text('Fullmetal Alchemist: Brotherhood'), findsNothing);
  });

  testWidgets('sorts the library alphabetically by default', (
    WidgetTester tester,
  ) async {
    // Zankyou is the most recently updated but sorts after Akira.
    await pumpApp(
      tester,
      repo: inMemoryLibrary(<Entry>[
        Entry(
          malId: 1,
          title: 'Zankyou no Terror',
          status: WatchStatus.watching,
          updatedAt: DateTime(2024, 3),
        ),
        Entry(
          malId: 2,
          title: 'Akira',
          status: WatchStatus.watching,
          updatedAt: DateTime(2023, 12),
        ),
      ]),
    );

    final List<String> titlesInOrder = tester
        .widgetList<EntryCard>(find.byType(EntryCard))
        .map((EntryCard card) => card.entry.title)
        .toList();

    expect(titlesInOrder, <String>['Akira', 'Zankyou no Terror']);
  });

  testWidgets('persists the sort order and reverses it when selected again', (
    WidgetTester tester,
  ) async {
    await _pumpSampleLibrary(tester);
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await tester.tap(find.byIcon(Icons.filter_list));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Última modificación'));
    await tester.pumpAndSettle();
    expect(prefs.getString('library.order'), 'recent');
    expect(prefs.getBool('library.order.reversed'), false);

    await tester.tap(find.text('Última modificación'));
    await tester.pumpAndSettle();
    expect(prefs.getBool('library.order.reversed'), true);
  });

  testWidgets('announces the active sort and its direction', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await _pumpSampleLibrary(tester);

    await tester.tap(find.byIcon(Icons.filter_list));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Última modificación'));
    await tester.pumpAndSettle();

    SemanticsNode recent() =>
        tester.getSemantics(find.text('Última modificación'));
    expect(recent(), isSemantics(isSelected: true));
    expect(recent().label, contains('Ascendente'));

    await tester.tap(find.text('Última modificación'));
    await tester.pumpAndSettle();

    expect(recent().label, contains('Descendente'));
    semantics.dispose();
  });

  testWidgets('fits a long title in a compact cell', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      repo: inMemoryLibrary(<Entry>[
        Entry(
          malId: 1,
          title:
              'A deliberately long title that wraps past two lines and '
              'must not overflow its grid cell',
          status: WatchStatus.watching,
          updatedAt: DateTime(2024),
        ),
      ]),
    );

    expect(tester.takeException(), isNull);
  });
}
