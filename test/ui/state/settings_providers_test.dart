import 'package:anihub/ui/providers.dart';
import 'package:anihub/ui/state/settings_providers.dart';
import 'package:anihub/ui/theme/accents.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final ProviderContainer container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('starts from the defaults', () async {
    final ProviderContainer container = await _container(<String, Object>{});

    expect(container.read(themeModeProvider), ThemeMode.system);
    expect(container.read(pureBlackProvider), isFalse);
    expect(container.read(accentProvider), AppAccent.indigo);
    expect(container.read(appLanguageProvider), AppLanguage.system);
  });

  test('reads the saved values', () async {
    final ProviderContainer container = await _container(<String, Object>{
      'appearance.themeMode': 'light',
      'appearance.pureBlack': true,
      'appearance.accent': 'pink',
      'general.language': 'en',
    });

    expect(container.read(themeModeProvider), ThemeMode.light);
    expect(container.read(pureBlackProvider), isTrue);
    expect(container.read(accentProvider), AppAccent.pink);
    expect(container.read(appLanguageProvider), AppLanguage.en);
  });

  test('falls back to the default for an unknown saved value', () async {
    final ProviderContainer container = await _container(<String, Object>{
      'appearance.themeMode': 'sepia',
      'appearance.accent': 'violet',
      'general.language': 'fr',
    });

    expect(container.read(themeModeProvider), ThemeMode.system);
    expect(container.read(accentProvider), AppAccent.indigo);
    expect(container.read(appLanguageProvider), AppLanguage.system);
  });

  test('saves a new value', () async {
    final ProviderContainer container = await _container(<String, Object>{});

    container.read(accentProvider.notifier).set(AppAccent.teal);
    container.read(pureBlackProvider.notifier).set(true);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(container.read(accentProvider), AppAccent.teal);
    expect(prefs.getString('appearance.accent'), 'teal');
    expect(prefs.getBool('appearance.pureBlack'), isTrue);
  });
}
