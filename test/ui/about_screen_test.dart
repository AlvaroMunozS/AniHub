import 'dart:async';

import 'package:anihub/domain/errors/update_exception.dart';
import 'package:anihub/ui/project_links.dart';
import 'package:anihub/ui/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_app_installer.dart';
import '../support/fake_external_links.dart';
import '../support/fake_release_source.dart';
import 'support/pump_app.dart';

const String _updateRow = 'Buscar actualizaciones';
const String _prereleaseRow = 'Recibir versiones preliminares';

Future<void> _pumpAbout(
  WidgetTester tester, {
  FakeReleaseSource? releaseSource,
  FakeAppInstaller? installer,
  FakeExternalLinks? links,
  Map<String, Object> prefs = const <String, Object>{},
}) {
  return pumpApp(
    tester,
    releaseSource: releaseSource,
    installer: installer,
    links: links,
    prefs: prefs,
    initialLocation: RoutePaths.about,
  );
}

Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

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

  testWidgets('shows the version and credits MyAnimeList', (
    WidgetTester tester,
  ) async {
    await _pumpAbout(tester);

    expect(find.text('1.2.3'), findsOneWidget);
    expect(find.text('Comprueba si hay una versión nueva'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('no está afiliada a MyAnimeList'),
      100,
    );
    expect(
      find.textContaining('no está afiliada a MyAnimeList'),
      findsOneWidget,
    );
  });

  testWidgets('makes no request until the user checks', (
    WidgetTester tester,
  ) async {
    final FakeReleaseSource source = FakeReleaseSource();

    await _pumpAbout(tester, releaseSource: source);

    expect(source.requests, isEmpty);
  });

  testWidgets('says when the installed version is the latest', (
    WidgetTester tester,
  ) async {
    await _pumpAbout(
      tester,
      releaseSource: FakeReleaseSource(release: sampleRelease('1.2.3')),
    );
    await _tapText(tester, _updateRow);

    expect(find.text('Tienes la última versión'), findsOneWidget);
  });

  testWidgets('downloads and installs a newer version on a second tap', (
    WidgetTester tester,
  ) async {
    final FakeAppInstaller installer = FakeAppInstaller();
    await _pumpAbout(
      tester,
      releaseSource: FakeReleaseSource(release: sampleRelease('1.3.0')),
      installer: installer,
    );

    await _tapText(tester, _updateRow);
    expect(
      find.text('Versión 1.3.0 disponible · Toca para instalar'),
      findsOneWidget,
    );
    expect(installer.installed, isEmpty);

    await tester.tap(find.text(_updateRow));
    await tester.pump();
    installer.progress(0.45);
    await tester.pump();
    expect(find.text('Descargando… 45 %'), findsOneWidget);

    installer.progress(1);
    await tester.pump();
    expect(find.text('Instalando…'), findsOneWidget);
    expect(installer.installed.single.version.toString(), '1.3.0');
  });

  testWidgets('offers the update again when the installation is cancelled', (
    WidgetTester tester,
  ) async {
    final FakeAppInstaller installer = FakeAppInstaller();
    await _pumpAbout(
      tester,
      releaseSource: FakeReleaseSource(release: sampleRelease('1.3.0')),
      installer: installer,
    );
    await _tapText(tester, _updateRow);
    await tester.tap(find.text(_updateRow));
    await tester.pump();

    installer.completer.complete(false);
    await tester.pumpAndSettle();

    expect(
      find.text('Versión 1.3.0 disponible · Toca para instalar'),
      findsOneWidget,
    );
  });

  for (final (Object error, String message) in <(Object, String)>[
    (
      const UpdateNetworkException('offline'),
      'No se pudo comprobar. Revisa la conexión',
    ),
    (
      const UpdateRateLimitException(),
      'GitHub ha limitado las consultas. Prueba más tarde',
    ),
  ]) {
    testWidgets('reports a failed check: $message', (
      WidgetTester tester,
    ) async {
      final FakeReleaseSource source = FakeReleaseSource(error: error);
      await _pumpAbout(tester, releaseSource: source);

      await _tapText(tester, _updateRow);
      expect(find.text(message), findsOneWidget);

      source
        ..error = null
        ..release = sampleRelease('1.2.3');
      await _tapText(tester, _updateRow);
      expect(find.text('Tienes la última versión'), findsOneWidget);
    });
  }

  for (final (Object error, String message) in <(Object, String)>[
    (
      const UpdateNetworkException('offline'),
      'No se pudo descargar la actualización',
    ),
    (
      const UpdateChecksumException(),
      'La descarga está dañada. Vuelve a intentarlo',
    ),
    (
      const UpdateInstallException('rejected'),
      'No se pudo instalar la actualización',
    ),
  ]) {
    testWidgets('reports a failed installation and retries it: $message', (
      WidgetTester tester,
    ) async {
      final FakeAppInstaller installer = FakeAppInstaller();
      final FakeReleaseSource source = FakeReleaseSource(
        release: sampleRelease('1.3.0'),
      );
      await _pumpAbout(tester, releaseSource: source, installer: installer);
      await _tapText(tester, _updateRow);
      await tester.tap(find.text(_updateRow));
      await tester.pump();

      installer.completer.completeError(error);
      await tester.pumpAndSettle();
      expect(find.text(message), findsOneWidget);

      installer.completer = Completer<bool>();
      await tester.tap(find.text(_updateRow));
      await tester.pump();
      expect(installer.installed, hasLength(2));
      expect(source.requests, hasLength(1));
    });
  }

  testWidgets('asks for pre-releases once the switch is on and keeps it', (
    WidgetTester tester,
  ) async {
    final FakeReleaseSource source = FakeReleaseSource();
    await _pumpAbout(tester, releaseSource: source);

    await _tapText(tester, _prereleaseRow);
    await _tapText(tester, _updateRow);

    expect(source.requests, <bool>[true]);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('updates.includePrereleases'), isTrue);
  });

  testWidgets('reads the pre-release switch from the preferences', (
    WidgetTester tester,
  ) async {
    await _pumpAbout(
      tester,
      prefs: <String, Object>{'updates.includePrereleases': true},
    );

    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );
  });

  testWidgets('opens the project pages', (WidgetTester tester) async {
    final FakeExternalLinks links = FakeExternalLinks();
    await _pumpAbout(tester, links: links);

    for (final String row in <String>[
      'Novedades',
      'Código fuente',
      'Política de privacidad',
    ]) {
      await tester.scrollUntilVisible(find.text(row), 100);
      await _tapText(tester, row);
    }

    expect(links.opened, <Uri>[
      ProjectLinks.releases,
      ProjectLinks.repository,
      ProjectLinks.privacy,
    ]);
  });

  testWidgets('says when a link cannot be opened', (WidgetTester tester) async {
    await _pumpAbout(tester, links: FakeExternalLinks(opens: false));

    await _tapText(tester, 'Novedades');

    expect(find.text('No se pudo abrir el enlace'), findsOneWidget);
  });

  testWidgets('shows the open source licenses', (WidgetTester tester) async {
    await _pumpAbout(tester);

    await tester.scrollUntilVisible(
      find.text('Licencias de código abierto'),
      100,
    );
    await _tapText(tester, 'Licencias de código abierto');

    expect(find.byType(LicensePage), findsOneWidget);
  });
}
