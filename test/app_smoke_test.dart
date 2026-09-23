import 'package:anihub/ui/screens/library_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/sample_data.dart';
import 'ui/support/pump_app.dart';

void main() {
  testWidgets('starts on the library', (WidgetTester tester) async {
    await pumpApp(tester, repo: inMemoryLibrary(sampleEntries()));

    expect(find.byType(LibraryScreen), findsOneWidget);
    expect(find.text('One Piece'), findsOneWidget);
  });
}
