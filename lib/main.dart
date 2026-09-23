import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'infrastructure/backup/file_picker_library_backup_source.dart';
import 'infrastructure/cache/caching_anime_relations.dart';
import 'infrastructure/cache/shared_preferences_snapshot_store.dart';
import 'infrastructure/github/github_release_source.dart';
import 'infrastructure/images/anihub_image_cache.dart';
import 'infrastructure/links/url_launcher_external_links.dart';
import 'infrastructure/local/sqflite_entry_repository.dart';
import 'infrastructure/mal/mal_catalog.dart';
import 'infrastructure/mal/mal_client.dart';
import 'infrastructure/mal/mal_relations.dart';
import 'infrastructure/update/android_app_installer.dart';
import 'infrastructure/update/apk_downloader.dart';
import 'infrastructure/update/platform_package_installer.dart';
import 'ui/providers.dart';
import 'ui/router.dart';
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
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  // Opened once for the lifetime of the process and never closed explicitly;
  // the OS releases it when the process dies.
  final Database database = await openAniHubDatabase();
  final Directory cacheDir = await getTemporaryDirectory();
  runApp(
    ProviderScope(
      overrides: <Override>[
        sharedPreferencesProvider.overrideWithValue(prefs),
        entryRepositoryProvider.overrideWith(
          (Ref ref) => SqfliteEntryRepository(database),
        ),
        libraryBackupSourceProvider.overrideWithValue(
          const FilePickerLibraryBackupSource(),
        ),
        imageCacheManagerProvider.overrideWithValue(AniHubImageCache()),
        externalLinksProvider.overrideWithValue(
          const UrlLauncherExternalLinks(),
        ),
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
        animeRelationsProvider.overrideWith((Ref ref) {
          return CachingAnimeRelations(
            MalRelations(ref.watch(_malClientProvider)),
            SharedPreferencesSnapshotStore(
              ref.watch(sharedPreferencesProvider),
              relationsSnapshotKey,
            ),
          );
        }),
      ],
      child: const AniHubApp(),
    ),
  );
}

/// The app is in Spanish only, whatever the device language.
const Locale _locale = Locale('es');

class AniHubApp extends ConsumerWidget {
  const AniHubApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'AniHub',
      debugShowCheckedModeBanner: false,
      theme: buildDarkTheme(),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const <Locale>[_locale],
      locale: _locale,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
