import 'package:anihub/ui/widgets/stacked_covers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';

void main() {
  testWidgets('falls back to a single cover without urls', (
    WidgetTester tester,
  ) async {
    await pumpInScaffold(
      tester,
      const SizedBox(
        width: 48,
        height: 72,
        child: StackedCovers(urls: <String?>[]),
      ),
    );

    expect(find.byType(StackedCovers), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps every layer inside its box', (WidgetTester tester) async {
    await pumpInScaffold(
      tester,
      const Center(
        child: SizedBox(
          width: 48,
          height: 72,
          child: StackedCovers(urls: <String?>[null, null, null, null]),
        ),
      ),
    );

    expect(tester.getSize(find.byType(StackedCovers)), const Size(48, 72));
    expect(tester.takeException(), isNull);
  });
}
