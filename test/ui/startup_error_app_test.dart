import 'package:anihub/ui/startup_error_app.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('tells the user the library could not be opened', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.localesTestValue = const <Locale>[Locale('en')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    await tester.pumpWidget(const StartupErrorApp());

    expect(find.text('Could not open your library'), findsOneWidget);
  });

  testWidgets('is in Spanish on a Spanish device', (WidgetTester tester) async {
    tester.platformDispatcher.localesTestValue = const <Locale>[Locale('es')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    await tester.pumpWidget(const StartupErrorApp());

    expect(find.text('No se pudo abrir tu biblioteca'), findsOneWidget);
  });
}
