import 'package:anihub/domain/entities/entry.dart';
import 'package:anihub/domain/ports/anime_catalog.dart';
import 'package:anihub/domain/ports/anime_relations.dart';
import 'package:anihub/domain/ports/app_installer.dart';
import 'package:anihub/domain/ports/entry_repository.dart';
import 'package:anihub/domain/ports/external_links.dart';
import 'package:anihub/domain/ports/image_cache_storage.dart';
import 'package:anihub/domain/ports/library_backup_source.dart';
import 'package:anihub/domain/ports/release_source.dart';
import 'package:anihub/l10n/l10n.dart';
import 'package:anihub/main.dart';
import 'package:anihub/ui/providers.dart';
import 'package:anihub/ui/router.dart';
import 'package:anihub/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_anime_catalog.dart';
import '../../support/fake_anime_relations.dart';
import '../../support/fake_app_installer.dart';
import '../../support/fake_external_links.dart';
import '../../support/fake_image_cache_storage.dart';
import '../../support/fake_release_source.dart';
import '../../support/in_memory_entry_repository.dart';
import 'fake_cache_manager.dart';
import 'fake_library_backup_source.dart';

/// Logical size of the phone that app tests run on.
const Size _phoneSize = Size(400, 800);
const double _phonePixelRatio = 3;

/// The language that tests run in unless they say otherwise.
const Locale _testLocale = Locale('es');

/// The strings that tests find on screen by default.
final AppLocalizations spanish = lookupAppLocalizations(_testLocale);

/// Pumps the whole app at phone size and returns its router.
///
/// Every port gets a fake: [repo] defaults to an empty library, [catalog] to
/// [FakeAnimeCatalog], [relations] to a graph without relations and
/// [backupSource] to a cancelled file pick, [releaseSource] to no releases,
/// [installer] to one that never finishes, [links] to links that open and
/// [imageCacheStorage] to an empty cache.
/// Preferences start as [prefs] and the device languages are
/// [deviceLocales]. The app starts at [initialLocation], or on the library
/// through the app's own [routerProvider].
Future<GoRouter> pumpApp(
  WidgetTester tester, {
  EntryRepository? repo,
  AnimeCatalog? catalog,
  AnimeRelations? relations,
  LibraryBackupSource? backupSource,
  ReleaseSource? releaseSource,
  AppInstaller? installer,
  ExternalLinks? links,
  ImageCacheStorage? imageCacheStorage,
  Map<String, Object> prefs = const <String, Object>{},
  List<Locale> deviceLocales = const <Locale>[_testLocale],
  String? initialLocation,
}) async {
  tester.view.physicalSize = _phoneSize * _phonePixelRatio;
  tester.view.devicePixelRatio = _phonePixelRatio;
  tester.platformDispatcher.localesTestValue = deviceLocales;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);

  SharedPreferences.setMockInitialValues(prefs);
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  final GoRouter? router = initialLocation == null
      ? null
      : buildRouter(initialLocation: initialLocation);
  if (router != null) addTearDown(router.dispose);
  final EntryRepository repository = repo ?? inMemoryLibrary();

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        sharedPreferencesProvider.overrideWithValue(preferences),
        entryRepositoryProvider.overrideWithValue(repository),
        animeCatalogProvider.overrideWithValue(catalog ?? FakeAnimeCatalog()),
        animeRelationsProvider.overrideWithValue(
          relations ?? FakeAnimeRelations(),
        ),
        libraryBackupSourceProvider.overrideWithValue(
          backupSource ?? const FakeLibraryBackupSource(),
        ),
        imageCacheManagerProvider.overrideWithValue(FakeCacheManager()),
        imageCacheStorageProvider.overrideWithValue(
          imageCacheStorage ?? FakeImageCacheStorage(),
        ),
        releaseSourceProvider.overrideWithValue(
          releaseSource ?? FakeReleaseSource(),
        ),
        appInstallerProvider.overrideWithValue(installer ?? FakeAppInstaller()),
        externalLinksProvider.overrideWithValue(links ?? FakeExternalLinks()),
        if (router != null) routerProvider.overrideWithValue(router),
      ],
      child: const AniHubApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(AniHubApp)))
      .read(routerProvider);
}

/// Returns an in-memory library holding [entries], disposed when the test
/// ends.
InMemoryEntryRepository inMemoryLibrary([
  List<Entry> entries = const <Entry>[],
]) {
  final InMemoryEntryRepository repo = InMemoryEntryRepository(seed: entries);
  addTearDown(repo.dispose);
  return repo;
}

/// Pumps [child] alone inside the app theme of [brightness] and a
/// [Scaffold], in Spanish, with covers served by [cacheManager] and the
/// providers in [overrides].
Future<void> pumpInScaffold(
  WidgetTester tester,
  Widget child, {
  BaseCacheManager? cacheManager,
  Brightness brightness = Brightness.dark,
  List<Override> overrides = const <Override>[],
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        imageCacheManagerProvider.overrideWithValue(
          cacheManager ?? FakeCacheManager(),
        ),
        ...overrides,
      ],
      child: MaterialApp(
        theme: buildTheme(
          brightness: brightness,
          pureBlack: false,
          accent: AppAccent.indigo,
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: _testLocale,
        home: Scaffold(body: child),
      ),
    ),
  );
}
