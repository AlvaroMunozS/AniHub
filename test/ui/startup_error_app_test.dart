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
    expect(
      find.text(
        'Close the app and open it again. If it keeps happening, restart '
        'your phone or free up storage space. Your library has not been '
        'deleted.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('is in Spanish on a Spanish device', (WidgetTester tester) async {
    tester.platformDispatcher.localesTestValue = const <Locale>[Locale('es')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    await tester.pumpWidget(const StartupErrorApp());

    expect(find.text('No se pudo abrir tu biblioteca'), findsOneWidget);
    expect(
      find.text(
        'Cierra la app y vuelve a abrirla. Si sigue igual, reinicia el '
        'teléfono o libera espacio de almacenamiento. Tu biblioteca no se '
        'ha borrado.',
      ),
      findsOneWidget,
    );
  });
}
