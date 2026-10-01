import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    show AndroidFlutterLocalNotificationsPlugin;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'infrastructure/backup/file_picker_library_backups.dart';
import 'infrastructure/cache/caching_anime_relations.dart';
import 'infrastructure/cache/relations_store.dart';
import 'infrastructure/cache/relations_store_opener.dart';
import 'infrastructure/github/github_release_source.dart';
import 'infrastructure/images/anihub_image_cache.dart';
import 'infrastructure/images/cache_manager_image_cache_storage.dart';
import 'infrastructure/links/url_launcher_external_links.dart';
import 'infrastructure/local/sqflite_entry_repository.dart';
import 'infrastructure/mal/mal_catalog.dart';
import 'infrastructure/mal/mal_client.dart';
import 'infrastructure/mal/mal_relations.dart';
import 'infrastructure/notifications/local_notifications_airing_reminders.dart';
import 'infrastructure/update/android_app_installer.dart';
import 'infrastructure/update/apk_downloader.dart';
import 'infrastructure/update/platform_package_installer.dart';
import 'l10n/l10n.dart';
import 'ui/locale_resolution.dart';
import 'ui/providers.dart';
import 'ui/router.dart';
import 'ui/shell/airing_reminders_sync.dart';
import 'ui/startup_error_app.dart';
import 'ui/state/settings_providers.dart';
import 'ui/theme/app_theme.dart';

/// Shared by every network adapter so they use one connection pool that is
/// closed once.
final Provider<http.Client> _httpClientProvider = Provider<http.Client>((
  Ref ref,
) {
  final http.Client client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final Provider<MalClient> _malClientProvider = Provider<MalClient>((Ref ref) {
  return MalClient(
    ref.watch(_httpClientProvider),
    clientId: const String.fromEnvironment('MAL_CLIENT_ID'),
    timeout: const Duration(seconds: 10),
  );
});

/// Lists the bundled Inter font on the licenses page, which only collects
/// the licenses of Dart packages.
void _registerFontLicense() {
  LicenseRegistry.addLicense(() async* {
    final String license = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(<String>['Inter'], license);
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerFontLicense();
  runApp(await startAniHub(_buildApp));
}

/// Builds the app with [build], or the error screen when any startup step
/// throws, so that a failure never leaves the splash screen up.
@visibleForTesting
Future<Widget> startAniHub(Future<Widget> Function() build) async {
  try {
    return await build();
  } on Object catch (error, stack) {
    debugPrint('Startup failed: $error\n$stack');
    return const StartupErrorApp();
  }
}

Future<Widget> _buildApp() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  // Opened once for the lifetime of the process and never closed explicitly;
  // the OS releases them when the process dies. The library file is never
  // deleted, so a failure to open it ends in the error screen.
  final Database database = await openAniHubDatabase();
  final RelationsStore relationsStore = await openRelationsStore(prefs);
  final Directory cacheDir = await getTemporaryDirectory();
  final AniHubImageCache imageCache = AniHubImageCache();
  return ProviderScope(
    retry: noProviderRetry,
    overrides: <Override>[
      sharedPreferencesProvider.overrideWithValue(prefs),
      entryRepositoryProvider.overrideWith(
        (Ref ref) => SqfliteEntryRepository(database),
      ),
      libraryBackupsProvider.overrideWithValue(
        const FilePickerLibraryBackups(),
      ),
      imageCacheManagerProvider.overrideWithValue(imageCache),
      imageCacheStorageProvider.overrideWithValue(
        CacheManagerImageCacheStorage(
          imageCache,
          // Where `flutter_cache_manager` keeps the files of a cache by
          // default.
          Directory(p.join(cacheDir.path, AniHubImageCache.key)),
        ),
      ),
      externalLinksProvider.overrideWithValue(const UrlLauncherExternalLinks()),
      releaseSourceProvider.overrideWith((Ref ref) {
        return GitHubReleaseSource(
          ref.watch(_httpClientProvider),
          timeout: const Duration(seconds: 10),
        );
      }),
      appInstallerProvider.overrideWith((Ref ref) {
        return AndroidAppInstaller(
          ApkDownloader(
            ref.watch(_httpClientProvider),
            directory: cacheDir,
            timeout: const Duration(seconds: 30),
          ),
          const PlatformPackageInstaller(),
        );
      }),
      animeCatalogProvider.overrideWith((Ref ref) {
        return MalCatalog(ref.watch(_malClientProvider));
      }),
      airingRemindersProvider.overrideWithValue(
        LocalNotificationsAiringReminders(
          AndroidFlutterLocalNotificationsPlugin(),
        ),
      ),
      animeRelationsProvider.overrideWith((Ref ref) {
        return CachingAnimeRelations(
          MalRelations(ref.watch(_malClientProvider)),
          relationsStore,
        );
      }),
    ],
    child: const AniHubApp(),
  );
}

class AniHubApp extends ConsumerWidget {
  const AniHubApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppAccent accent = ref.watch(accentProvider);
    return MaterialApp.router(
      title: 'AniHub',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(
        brightness: Brightness.light,
        pureBlack: false,
        accent: accent,
      ),
      darkTheme: buildTheme(
        brightness: Brightness.dark,
        pureBlack: ref.watch(pureBlackProvider),
        accent: accent,
      ),
      themeMode: ref.watch(themeModeProvider),
      // Screens without an app bar would otherwise keep the launch window's
      // status bar icons.
      builder: (BuildContext context, Widget? child) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: systemOverlayStyleFor(Theme.of(context).brightness),
          child: AiringRemindersSync(child: child!),
        );
      },
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // A chosen language goes through `locale`: Flutter resolves the device
      // languages only when they change, so a callback that read the
      // preference would not apply it until then.
      locale: ref.watch(appLanguageProvider).locale,
      localeListResolutionCallback: (
        List<Locale>? locales,
        Iterable<Locale> supported,
      ) => resolveAppLocale(locales),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
