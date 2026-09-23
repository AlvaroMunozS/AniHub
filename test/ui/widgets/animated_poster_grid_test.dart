import 'package:anihub/application/usecases/usecases.dart';
import 'package:anihub/domain/entities/entry.dart';
import 'package:anihub/domain/values/watch_status.dart';
import 'package:anihub/ui/widgets/entry_card.dart';
import 'package:anihub/ui/widgets/library/animated_poster_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';

List<LibraryItem> _entries(int count) {
  final DateTime now = DateTime.now();
  return <LibraryItem>[
    for (int i = 0; i < count; i++)
      LibraryEntryItem(
        Entry(
          malId: i,
          title: 'Anime $i',
          status: WatchStatus.watching,
          updatedAt: now,
        ),
      ),
  ];
}

void main() {
  testWidgets(
    'builds only the cells near the viewport and scrolls to the last one',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpInScaffold(
        tester,
        AnimatedPosterGrid(
          items: _entries(200),
          expanded: const <int>{},
          onOpen: (_) {},
          onToggle: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EntryCard).evaluate().length, lessThan(40));

      await tester.dragUntilVisible(
        find.widgetWithText(EntryCard, 'Anime 199'),
        find.byType(AnimatedPosterGrid),
        const Offset(0, -1000),
      );

      expect(find.widgetWithText(EntryCard, 'Anime 199'), findsOneWidget);
    },
  );
}
