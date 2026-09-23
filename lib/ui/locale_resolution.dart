import 'package:flutter/widgets.dart';

import '../l10n/l10n.dart';

/// Used when none of the device languages has a translation.
const Locale _fallbackLocale = Locale('en');

/// Picks the app language from the device languages, in the user's order of
/// preference.
///
/// Any regional variant counts, so `es_MX` resolves to Spanish.
Locale resolveAppLocale(List<Locale>? deviceLocales) {
  for (final Locale device in deviceLocales ?? const <Locale>[]) {
    for (final Locale supported in AppLocalizations.supportedLocales) {
      if (supported.languageCode == device.languageCode) return supported;
    }
  }
  return _fallbackLocale;
}
