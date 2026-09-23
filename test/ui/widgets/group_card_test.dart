import 'package:anihub/ui/widgets/group_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';

void main() {
  testWidgets('shows the label and reports taps', (WidgetTester tester) async {
    bool tapped = false;

    await pumpInScaffold(
      tester,
      SizedBox(
        width: 160,
        child: GroupCard(
          label: 'Steins;Gate',
          coverUrls: const <String?>[null, null],
          expanded: false,
          onTap: () => tapped = true,
        ),
      ),
    );

    expect(find.text('Steins;Gate'), findsOneWidget);

    await tester.tap(find.byType(GroupCard));
    expect(tapped, isTrue);
  });

  testWidgets('tells accessibility services whether it is expanded', (
    WidgetTester tester,
  ) async {
    await pumpInScaffold(
      tester,
      SizedBox(
        width: 160,
        child: GroupCard(
          label: 'Steins;Gate',
          coverUrls: const <String?>[null, null],
          expanded: true,
          onTap: () {},
        ),
      ),
    );

    expect(
      tester.getSemantics(find.byType(GroupCard)),
      isSemantics(
        isButton: true,
        hasExpandedState: true,
        isExpanded: true,
        hasTapAction: true,
      ),
    );
  });
}
