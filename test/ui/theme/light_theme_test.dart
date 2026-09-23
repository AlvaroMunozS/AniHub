import 'package:anihub/domain/values/watch_status.dart';
import 'package:anihub/ui/providers.dart';
import 'package:anihub/ui/screens/library_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_anime_relations.dart';
import '../../support/sample_data.dart';
import '../support/pump_app.dart';

void main() {
  testWidgets('renders the library in the light theme', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await pumpInScaffold(
      tester,
      const LibraryScreen(status: WatchStatus.watching),
      brightness: Brightness.light,
      overrides: <Override>[
        sharedPreferencesProvider.overrideWithValue(prefs),
        entryRepositoryProvider.overrideWithValue(
          inMemoryLibrary(sampleEntries()),
        ),
        animeRelationsProvider.overrideWithValue(FakeAnimeRelations()),
      ],
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('One Piece'), findsOneWidget);
    expect(
      Theme.of(tester.element(find.text('One Piece'))).brightness,
      Brightness.light,
    );
  });
}
