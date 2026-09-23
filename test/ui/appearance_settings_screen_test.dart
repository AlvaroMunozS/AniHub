import 'package:anihub/ui/router.dart';
import 'package:anihub/ui/screens/settings/appearance_settings_screen.dart';
import 'package:anihub/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/pump_app.dart';

Future<void> _pumpAppearance(
  WidgetTester tester, {
  Map<String, Object> prefs = const <String, Object>{},
  List<Locale> deviceLocales = const <Locale>[Locale('es')],
}) {
  return pumpApp(
    tester,
    prefs: prefs,
    deviceLocales: deviceLocales,
    initialLocation: RoutePaths.appearanceSettings,
  );
}

ThemeData _theme(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(AppearanceSettingsScreen)));

SwitchListTile _pureBlackSwitch(WidgetTester tester) =>
    tester.widget(find.widgetWithText(SwitchListTile, 'Negro puro'));

void main() {
  testWidgets('follows the system theme by default', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await _pumpAppearance(tester);

    expect(_theme(tester).brightness, Brightness.light);
  });

  testWidgets('switches the theme and saves the choice', (
    WidgetTester tester,
  ) async {
    await _pumpAppearance(tester);

    await tester.tap(find.text('Claro'));
    await tester.pumpAndSettle();
    expect(_theme(tester).brightness, Brightness.light);

    await tester.tap(find.text('Oscuro'));
    await tester.pumpAndSettle();
    expect(_theme(tester).brightness, Brightness.dark);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('appearance.themeMode'), 'dark');
  });

  testWidgets('applies pure black only to the dark theme', (
    WidgetTester tester,
  ) async {
    await _pumpAppearance(
      tester,
      prefs: const <String, Object>{'appearance.themeMode': 'dark'},
    );

    await tester.tap(find.text('Negro puro'));
    await tester.pumpAndSettle();
    expect(_theme(tester).scaffoldBackgroundColor, const Color(0xFF000000));
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('appearance.pureBlack'), isTrue);

    await tester.tap(find.text('Claro'));
    await tester.pumpAndSettle();
    expect(_pureBlackSwitch(tester).onChanged, isNull);
    expect(_pureBlackSwitch(tester).value, isTrue);
    expect(
      _theme(tester).scaffoldBackgroundColor,
      AppPalette.light(AppAccent.indigo).background,
    );
  });

  testWidgets('applies and saves the accent', (WidgetTester tester) async {
    await _pumpAppearance(
      tester,
      prefs: const <String, Object>{'appearance.themeMode': 'dark'},
    );

    await tester.tap(find.bySemanticsLabel('Verde'));
    await tester.pumpAndSettle();

    expect(_theme(tester).colorScheme.primary, AppAccent.green.dark);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('appearance.accent'), 'green');
  });

  testWidgets('switches the language at once and saves it', (
    WidgetTester tester,
  ) async {
    await _pumpAppearance(tester);

    expect(find.text('Sistema'), findsNWidgets(2));
    await tester.tap(find.text('Idioma de la aplicación'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(find.text('App language'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('general.language'), 'en');
  });

  testWidgets('goes back to the device language with the system option', (
    WidgetTester tester,
  ) async {
    await _pumpAppearance(
      tester,
      prefs: const <String, Object>{'general.language': 'en'},
    );
    expect(find.text('App language'), findsOneWidget);

    await tester.tap(find.text('App language'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('System'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Idioma de la aplicación'), findsOneWidget);
  });

  testWidgets('keeps the language when the dialog is cancelled', (
    WidgetTester tester,
  ) async {
    await _pumpAppearance(tester);

    await tester.tap(find.text('Idioma de la aplicación'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.text('Idioma de la aplicación'), findsOneWidget);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('general.language'), isNull);
  });
}
