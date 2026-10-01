import 'package:anihub/ui/widgets/pill_search_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';

Finder get _mine => find.byTooltip(spanish.searchAiringMine);

Future<TextEditingController> _pump(
  WidgetTester tester, {
  ValueChanged<bool>? onToggleMine,
  bool mineActive = false,
}) async {
  final TextEditingController controller = TextEditingController();
  addTearDown(controller.dispose);
  await pumpInScaffold(
    tester,
    PillSearchBar(
      controller: controller,
      hintText: 'Buscar',
      onChanged: (_) {},
      onClear: controller.clear,
      onToggleMine: onToggleMine,
      mineActive: mineActive,
    ),
  );
  return controller;
}

double _fieldWidth(WidgetTester tester) =>
    tester.getSize(find.byType(TextField)).width;

void main() {
  testWidgets('has no bookmark unless asked for one', (
    WidgetTester tester,
  ) async {
    await _pump(tester);

    expect(_mine, findsNothing);
  });

  testWidgets('toggles the bookmark', (WidgetTester tester) async {
    final List<bool> toggled = <bool>[];
    await _pump(tester, onToggleMine: toggled.add);

    expect(tester.getSemantics(_mine), isSemantics(isSelected: false));
    await tester.tap(_mine);

    expect(toggled, <bool>[true]);
  });

  testWidgets('marks the bookmark as selected while active', (
    WidgetTester tester,
  ) async {
    final List<bool> toggled = <bool>[];
    await _pump(tester, onToggleMine: toggled.add, mineActive: true);

    expect(tester.getSemantics(_mine), isSemantics(isSelected: true));
    await tester.tap(_mine);
    expect(toggled, <bool>[false]);
  });

  testWidgets('gives the bookmark slot to the clear button while typing', (
    WidgetTester tester,
  ) async {
    final TextEditingController controller = await _pump(
      tester,
      onToggleMine: (_) {},
    );

    controller.text = 'f';
    await tester.pump();

    expect(_mine, findsNothing);
    expect(find.byTooltip(spanish.searchBarClear), findsOneWidget);
  });

  testWidgets('keeps the field as wide with the bookmark, the clear button '
      'or neither', (WidgetTester tester) async {
    final TextEditingController controller = await _pump(
      tester,
      onToggleMine: (_) {},
    );
    final double withBookmark = _fieldWidth(tester);

    controller.text = 'f';
    await tester.pump();
    final double withClear = _fieldWidth(tester);

    await _pump(tester);
    final double withNeither = _fieldWidth(tester);

    expect(withClear, withBookmark);
    expect(withNeither, withBookmark);
  });
}
