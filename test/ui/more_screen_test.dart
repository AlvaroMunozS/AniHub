import 'package:anihub/ui/router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'support/pump_app.dart';

String _path(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.path;

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'AniHub',
      packageName: 'com.example.anihub',
      version: '1.2.3',
      buildNumber: '4',
      buildSignature: '',
    );
  });

  testWidgets('opens About without showing the version first', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pumpApp(
      tester,
      initialLocation: RoutePaths.more,
    );

    expect(find.textContaining('1.2.3'), findsNothing);

    await tester.tap(find.text('Acerca de'));
    await tester.pumpAndSettle();

    expect(_path(router), RoutePaths.about);
  });

  testWidgets('opens Settings and each of its categories', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pumpApp(
      tester,
      initialLocation: RoutePaths.more,
    );

    await tester.tap(find.text('Configuración'));
    await tester.pumpAndSettle();
    expect(_path(router), RoutePaths.settings);

    for (final (String label, String path) in <(String, String)>[
      ('Apariencia', RoutePaths.appearanceSettings),
      ('Copia de seguridad', RoutePaths.backupSettings),
      ('Almacenamiento', RoutePaths.storageSettings),
    ]) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(_path(router), path);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(_path(router), RoutePaths.settings);
    }
  });
}
