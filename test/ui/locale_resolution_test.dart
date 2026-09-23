import 'package:anihub/ui/locale_resolution.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses Spanish on a Spanish device', () {
    expect(resolveAppLocale(const <Locale>[Locale('es')]), const Locale('es'));
  });

  test('accepts any regional variant', () {
    expect(
      resolveAppLocale(const <Locale>[Locale('es', 'MX')]),
      const Locale('es'),
    );
    expect(
      resolveAppLocale(const <Locale>[Locale('en', 'GB')]),
      const Locale('en'),
    );
  });

  test('takes the first translated language in the device order', () {
    expect(
      resolveAppLocale(const <Locale>[
        Locale('fr'),
        Locale('es'),
        Locale('en'),
      ]),
      const Locale('es'),
    );
  });

  test('falls back to English without a translated language', () {
    expect(resolveAppLocale(const <Locale>[Locale('fr')]), const Locale('en'));
    expect(resolveAppLocale(const <Locale>[]), const Locale('en'));
    expect(resolveAppLocale(null), const Locale('en'));
  });
}
