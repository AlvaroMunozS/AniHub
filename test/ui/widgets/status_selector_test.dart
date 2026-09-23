import 'package:anihub/domain/values/watch_status.dart';
import 'package:anihub/ui/theme/app_theme.dart';
import 'package:anihub/ui/widgets/status_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const double _collapsedWidth = 160;
const double _expandedWidth = 264;

Widget _host({
  required WatchStatus? current,
  required ValueChanged<WatchStatus> onSelected,
  bool enabled = true,
}) {
  return MaterialApp(
    theme: buildTheme(
      brightness: Brightness.dark,
      pureBlack: false,
      accent: AppAccent.indigo,
    ),
    home: Scaffold(
      body: Column(
        children: <Widget>[
          Align(
            alignment: Alignment.topLeft,
            child: StatusSelector(
              current: current,
              onSelected: onSelected,
              collapsedWidth: _collapsedWidth,
              expandedWidth: _expandedWidth,
              enabled: enabled,
            ),
          ),
          // A tap target outside the selector.
          const Text('outside'),
        ],
      ),
    ),
  );
}

/// Returns the icon shown above [label], so tests can tell filled from
/// outlined icons without hardcoding [IconData] values.
IconData _iconOf(WidgetTester tester, String label) {
  return tester
      .widget<Icon>(
        find.descendant(
          of: find.ancestor(
            of: find.text(label),
            matching: find.byType(StatusActionButton),
          ),
          matching: find.byType(Icon),
        ),
      )
      .icon!;
}

void main() {
  testWidgets('shows only the current status when collapsed', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(current: WatchStatus.watching, onSelected: (_) {}),
    );

    expect(find.text('Viendo'), findsOneWidget);
    expect(find.text('Pendiente'), findsOneWidget);
    expect(find.text('Completado'), findsOneWidget);

    // Collapsed, the other statuses share the current one's slot.
    final Offset watching = tester.getCenter(find.text('Viendo'));
    final Offset planned = tester.getCenter(find.text('Pendiente'));
    expect(planned, watching);
  });

  testWidgets('expands every status in display order on tap', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(current: WatchStatus.watching, onSelected: (_) {}),
    );

    await tester.tap(find.text('Viendo'));
    await tester.pumpAndSettle();

    final double plannedX = tester.getCenter(find.text('Pendiente')).dx;
    final double watchingX = tester.getCenter(find.text('Viendo')).dx;
    final double completedX = tester.getCenter(find.text('Completado')).dx;

    expect(plannedX, lessThan(watchingX));
    expect(watchingX, lessThan(completedX));
  });

  testWidgets('fills the current status icon and outlines the others', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(current: WatchStatus.watching, onSelected: (_) {}),
    );
    await tester.tap(find.text('Viendo'));
    await tester.pumpAndSettle();

    expect(_iconOf(tester, 'Viendo'), Icons.visibility);
    expect(_iconOf(tester, 'Pendiente'), Icons.schedule_outlined);
    expect(_iconOf(tester, 'Completado'), Icons.check_circle_outline);
  });

  testWidgets('reports another status and collapses showing it once applied', (
    WidgetTester tester,
  ) async {
    WatchStatus? chosen;
    void onSelected(WatchStatus status) => chosen = status;
    await tester.pumpWidget(
      _host(current: WatchStatus.watching, onSelected: onSelected),
    );

    await tester.tap(find.text('Viendo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Completado'));
    await tester.pumpWidget(_host(current: chosen, onSelected: onSelected));
    await tester.pumpAndSettle();

    expect(chosen, WatchStatus.completed);
    final Offset watching = tester.getCenter(find.text('Viendo'));
    final Offset completed = tester.getCenter(find.text('Completado'));
    expect(completed, watching);
    expect(_iconOf(tester, 'Completado'), Icons.check_circle);
  });

  testWidgets('keeps showing the current status when a choice is not applied', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(current: WatchStatus.watching, onSelected: (_) {}),
    );

    await tester.tap(find.text('Viendo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Completado'));
    await tester.pumpAndSettle();

    expect(_iconOf(tester, 'Viendo'), Icons.visibility);
    expect(_iconOf(tester, 'Completado'), Icons.check_circle_outline);
  });

  testWidgets('collapses without selecting when the current one is tapped', (
    WidgetTester tester,
  ) async {
    bool called = false;
    await tester.pumpWidget(
      _host(current: WatchStatus.watching, onSelected: (_) => called = true),
    );

    await tester.tap(find.text('Viendo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Viendo'));
    await tester.pumpAndSettle();

    expect(called, isFalse);
    final Offset watching = tester.getCenter(find.text('Viendo'));
    final Offset planned = tester.getCenter(find.text('Pendiente'));
    expect(planned, watching);
  });

  testWidgets('collapses without selecting on an outside tap', (
    WidgetTester tester,
  ) async {
    bool called = false;
    await tester.pumpWidget(
      _host(current: WatchStatus.watching, onSelected: (_) => called = true),
    );

    await tester.tap(find.text('Viendo'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('outside'));
    await tester.pumpAndSettle();

    expect(called, isFalse);
    final Offset watching = tester.getCenter(find.text('Viendo'));
    final Offset planned = tester.getCenter(find.text('Pendiente'));
    expect(planned, watching);
  });

  testWidgets('shows an add button and no filled icon without a status', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_host(current: null, onSelected: (_) {}));

    expect(find.text('Añadir'), findsOneWidget);

    await tester.tap(find.text('Añadir'));
    await tester.pumpAndSettle();

    expect(_iconOf(tester, 'Pendiente'), Icons.schedule_outlined);
    expect(_iconOf(tester, 'Viendo'), Icons.visibility_outlined);
    expect(_iconOf(tester, 'Completado'), Icons.check_circle_outline);
  });

  testWidgets('announces that the current status opens the picker', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(current: WatchStatus.watching, onSelected: (_) {}),
    );

    expect(
      tester.getSemantics(find.text('Viendo')),
      isSemantics(
        isSelected: true,
        hasExpandedState: true,
        isExpanded: false,
        onTapHint: 'Cambiar estado',
      ),
    );

    await tester.tap(find.text('Viendo'));
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.text('Viendo')),
      isSemantics(hasExpandedState: true, isExpanded: true),
    );
    semantics.dispose();
  });

  testWidgets('does not expand when disabled', (WidgetTester tester) async {
    await tester.pumpWidget(
      _host(current: WatchStatus.watching, onSelected: (_) {}, enabled: false),
    );

    await tester.tap(find.text('Viendo'), warnIfMissed: false);
    await tester.pumpAndSettle();

    final Offset watching = tester.getCenter(find.text('Viendo'));
    final Offset planned = tester.getCenter(find.text('Pendiente'));
    expect(planned, watching);
  });
}
