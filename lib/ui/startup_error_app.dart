import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'locale_resolution.dart';
import 'theme/app_theme.dart';

/// Shown instead of the app when the library database cannot be opened.
///
/// It stands alone, without providers or preferences, since it runs when
/// startup has already failed.
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AniHub',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(
        brightness: Brightness.light,
        pureBlack: false,
        accent: AppAccent.values.first,
      ),
      darkTheme: buildTheme(
        brightness: Brightness.dark,
        pureBlack: false,
        accent: AppAccent.values.first,
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      localeListResolutionCallback: (
        List<Locale>? locales,
        Iterable<Locale> supported,
      ) => resolveAppLocale(locales),
      home: const _StartupErrorScreen(),
    );
  }
}

class _StartupErrorScreen extends StatelessWidget {
  const _StartupErrorScreen();

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                context.l10n.startupErrorTitle,
                style: text.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                context.l10n.startupErrorMessage,
                style: text.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
