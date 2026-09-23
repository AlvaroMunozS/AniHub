import 'package:anihub/ui/screens/library_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/sample_data.dart';
import 'ui/support/pump_app.dart';

void main() {
  testWidgets('starts on the library', (WidgetTester tester) async {
    await pumpApp(tester, repo: inMemoryLibrary(sampleEntries()));

    expect(find.byType(LibraryScreen), findsOneWidget);
    expect(find.text('One Piece'), findsOneWidget);
  });

  testWidgets('is in English on an English device', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      repo: inMemoryLibrary(sampleEntries()),
      deviceLocales: const <Locale>[Locale('en', 'US')],
    );

    for (final String label in <String>['Library', 'Browse', 'More']) {
      expect(find.text(label), findsOneWidget);
    }
    for (final String label in <String>['Watching', 'Planned', 'Completed']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Biblioteca'), findsNothing);
  });

  testWidgets('falls back to English on an untranslated device language', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, deviceLocales: const <Locale>[Locale('fr')]);

    expect(find.text('Your library is empty'), findsOneWidget);
  });
}
