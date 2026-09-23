import 'dart:async';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../report_error.dart';
import '../theme/accents.dart';

/// The app language the user picked.
enum AppLanguage {
  system(null),
  es(Locale('es')),
  en(Locale('en'));

  const AppLanguage(this.locale);

  /// The locale the app is set to, or null to follow the device languages.
  final Locale? locale;
}

/// An enum preference stored by name in `SharedPreferences`.
///
/// A stored name that is not one of [_values], as after a value is removed,
/// reads as [_fallback].
class EnumPreferenceNotifier<T extends Enum> extends Notifier<T> {
  EnumPreferenceNotifier(this._key, this._values, this._fallback);

  final String _key;
  final List<T> _values;
  final T _fallback;

  @override
  T build() {
    final String? name = ref.watch(sharedPreferencesProvider).getString(_key);
    return _values.asNameMap()[name] ?? _fallback;
  }

  void set(T value) {
    state = value;
    unawaited(ref.read(sharedPreferencesProvider).setString(_key, value.name));
  }
}

final NotifierProvider<EnumPreferenceNotifier<ThemeMode>, ThemeMode>
themeModeProvider =
    NotifierProvider<EnumPreferenceNotifier<ThemeMode>, ThemeMode>(
      () => EnumPreferenceNotifier<ThemeMode>(
        'appearance.themeMode',
        ThemeMode.values,
        ThemeMode.system,
      ),
    );

final NotifierProvider<EnumPreferenceNotifier<AppAccent>, AppAccent>
accentProvider = NotifierProvider<EnumPreferenceNotifier<AppAccent>, AppAccent>(
  () => EnumPreferenceNotifier<AppAccent>(
    'appearance.accent',
    AppAccent.values,
    AppAccent.indigo,
  ),
);

final NotifierProvider<EnumPreferenceNotifier<AppLanguage>, AppLanguage>
appLanguageProvider =
    NotifierProvider<EnumPreferenceNotifier<AppLanguage>, AppLanguage>(
      () => EnumPreferenceNotifier<AppLanguage>(
        'general.language',
        AppLanguage.values,
        AppLanguage.system,
      ),
    );

const String _pureBlackPrefsKey = 'appearance.pureBlack';

/// Whether the dark theme uses pure black surfaces.
class PureBlackNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref.watch(sharedPreferencesProvider).getBool(_pureBlackPrefsKey) ?? false;

  void set(bool value) {
    state = value;
    unawaited(
      ref.read(sharedPreferencesProvider).setBool(_pureBlackPrefsKey, value),
    );
  }
}

final NotifierProvider<PureBlackNotifier, bool> pureBlackProvider =
    NotifierProvider<PureBlackNotifier, bool>(PureBlackNotifier.new);

/// Disk space taken by the cached covers, measured again each time the
/// storage screen opens.
final FutureProvider<int> imageCacheSizeProvider =
    FutureProvider.autoDispose<int>(
      (Ref ref) => reportingUnexpected(
        ref.watch(imageCacheStorageProvider).sizeInBytes(),
        isExpected: (Object error) => false,
      ),
    );
