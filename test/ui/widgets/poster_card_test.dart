import 'package:anihub/ui/widgets/poster_card.dart';
import 'package:anihub/ui/widgets/poster_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';

void main() {
  testWidgets('does not overflow at double text size', (
    WidgetTester tester,
  ) async {
    await pumpInScaffold(
      tester,
      PosterGrid(
        itemCount: 4,
        itemBuilder: (BuildContext context, int index) => const PosterCard(
          cover: ColoredBox(color: Colors.grey),
          title: 'Sousou no Frieren: a very long title that wraps',
        ),
      ),
      textScale: 2,
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(PosterCard), findsWidgets);
  });
}
