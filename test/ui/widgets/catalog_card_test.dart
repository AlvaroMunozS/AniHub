import 'package:anihub/domain/entities/catalog_anime.dart';
import 'package:anihub/ui/theme/app_theme.dart';
import 'package:anihub/ui/widgets/catalog_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';

const CatalogAnime _anime = CatalogAnime(
  malId: 21,
  title: 'One Piece',
  seasonYear: 1999,
  isAiring: true,
);

Future<void> _pump(
  WidgetTester tester, {
  required bool inLibrary,
  VoidCallback? onOpen,
}) {
  return pumpInScaffold(
    tester,
    SizedBox(
      width: 160,
      child: CatalogCard(anime: _anime, inLibrary: inLibrary, onOpen: onOpen),
    ),
  );
}

final Finder _dimming = find.byWidgetPredicate(
  (Widget widget) =>
      widget is DecoratedBox &&
      widget.decoration is BoxDecoration &&
      (widget.decoration as BoxDecoration).color == AppOverlays.dim,
);

void main() {
  testWidgets('has no label or dimming outside the library', (
    WidgetTester tester,
  ) async {
    await _pump(tester, inLibrary: false);

    expect(find.text('One Piece'), findsOneWidget);
    expect(find.text('En biblioteca'), findsNothing);
    expect(_dimming, findsNothing);
  });

  testWidgets('dims and labels the cover when already in the library', (
    WidgetTester tester,
  ) async {
    await _pump(tester, inLibrary: true);

    expect(find.text('One Piece'), findsOneWidget);
    expect(find.text('En biblioteca'), findsOneWidget);
    expect(_dimming, findsOneWidget);
  });

  testWidgets('opens the detail even when already in the library', (
    WidgetTester tester,
  ) async {
    bool tapped = false;
    await _pump(tester, inLibrary: true, onOpen: () => tapped = true);

    await tester.tap(find.byType(CatalogCard));
    expect(tapped, isTrue);
  });
}
