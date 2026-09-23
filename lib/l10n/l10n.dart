import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

extension AppLocalizationsContext on BuildContext {
  /// The user-facing strings in the app's current language.
  AppLocalizations get l10n => AppLocalizations.of(this);
}
