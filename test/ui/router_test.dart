import 'package:anihub/domain/values/watch_status.dart';
import 'package:anihub/ui/router.dart';
import 'package:anihub/ui/screens/anime_detail_screen.dart';
import 'package:anihub/ui/screens/library_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/pump_app.dart';

String _location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

void main() {
  testWidgets('opens a library tab as the initial location', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pumpApp(
      tester,
      initialLocation: RoutePaths.libraryFor(WatchStatus.completed),
    );

    expect(_location(router), '/library/completed');
    final LibraryScreen screen = tester.widget(find.byType(LibraryScreen));
    expect(screen.status, WatchStatus.completed);
  });

  testWidgets('redirects an unknown library tab to the watching tab', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pumpApp(
      tester,
      initialLocation: '/library/favorites',
    );

    expect(_location(router), '/library/watching');
  });

  testWidgets('opens a detail route as the initial location', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pumpApp(
      tester,
      initialLocation: RoutePaths.animeDetail(5114),
    );

    expect(_location(router), '/anime/5114');
    expect(find.byType(AnimeDetailScreen), findsOneWidget);
  });
}
