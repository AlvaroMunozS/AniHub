import 'package:anihub/domain/entities/entry.dart';
import 'package:anihub/domain/ports/anime_catalog.dart';
import 'package:anihub/domain/ports/anime_relations.dart';
import 'package:anihub/domain/ports/app_installer.dart';
import 'package:anihub/domain/ports/entry_repository.dart';
import 'package:anihub/domain/ports/external_links.dart';
import 'package:anihub/domain/ports/library_backup_source.dart';
import 'package:anihub/domain/ports/release_source.dart';
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
import '../../support/fake_release_source.dart';
import '../../support/in_memory_entry_repository.dart';
import 'fake_cache_manager.dart';
import 'fake_library_backup_source.dart';

/// Logical size of the phone that app tests run on.
const Size _phoneSize = Size(400, 800);
const double _phonePixelRatio = 3;

/// Pumps the whole app at phone size and returns its router.
///
/// Every port gets a fake: [repo] defaults to an empty library, [catalog] to
/// [FakeAnimeCatalog], [relations] to a graph without relations and
/// [backupSource] to a cancelled file pick, [releaseSource] to no releases,
/// [installer] to one that never finishes and [links] to links that open.
/// Preferences start as [prefs]. The app starts at
/// [initialLocation], or on the library through the app's own
/// [routerProvider].
Future<GoRouter> pumpApp(
  WidgetTester tester, {
  EntryRepository? repo,
  AnimeCatalog? catalog,
  AnimeRelations? relations,
  LibraryBackupSource? backupSource,
  ReleaseSource? releaseSource,
  AppInstaller? installer,
  ExternalLinks? links,
  Map<String, Object> prefs = const <String, Object>{},
  String? initialLocation,
}) async {
  tester.view.physicalSize = _phoneSize * _phonePixelRatio;
  tester.view.devicePixelRatio = _phonePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

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

/// Pumps [child] alone inside the app theme and a [Scaffold], with covers
/// served by [cacheManager].
Future<void> pumpInScaffold(
  WidgetTester tester,
  Widget child, {
  BaseCacheManager? cacheManager,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        imageCacheManagerProvider.overrideWithValue(
          cacheManager ?? FakeCacheManager(),
        ),
      ],
      child: MaterialApp(
        theme: buildDarkTheme(),
        home: Scaffold(body: child),
      ),
    ),
  );
}
