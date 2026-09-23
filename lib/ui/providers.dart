import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../application/usecases/usecases.dart';
import '../domain/ports/anime_catalog.dart';
import '../domain/ports/anime_relations.dart';
import '../domain/ports/entry_repository.dart';
import '../domain/ports/library_backup_source.dart';

// Providers that throw have no default implementation, so `lib/ui` never
// depends on adapters; `main()` and tests supply them through
// `ProviderScope.overrides`.

Never _notOverridden(String name) {
  throw UnimplementedError(
    '$name was not overridden; pass it through ProviderScope.overrides.',
  );
}

final Provider<SharedPreferences> sharedPreferencesProvider =
    Provider<SharedPreferences>(
      (Ref ref) => _notOverridden('sharedPreferencesProvider'),
    );

final Provider<EntryRepository> entryRepositoryProvider =
    Provider<EntryRepository>(
      (Ref ref) => _notOverridden('entryRepositoryProvider'),
    );

final Provider<AnimeCatalog> animeCatalogProvider = Provider<AnimeCatalog>(
  (Ref ref) => _notOverridden('animeCatalogProvider'),
);

final Provider<AnimeRelations> animeRelationsProvider =
    Provider<AnimeRelations>(
      (Ref ref) => _notOverridden('animeRelationsProvider'),
    );

final Provider<LibraryBackupSource> libraryBackupSourceProvider =
    Provider<LibraryBackupSource>(
      (Ref ref) => _notOverridden('libraryBackupSourceProvider'),
    );

/// Disk cache for the covers shown by `CoverImage`.
final Provider<BaseCacheManager> imageCacheManagerProvider =
    Provider<BaseCacheManager>(
      (Ref ref) => _notOverridden('imageCacheManagerProvider'),
    );

final Provider<ImportLibrary> importLibraryProvider = Provider<ImportLibrary>(
  (Ref ref) => ImportLibrary(ref.watch(entryRepositoryProvider)),
);

final FutureProvider<PackageInfo> packageInfoProvider =
    FutureProvider<PackageInfo>((Ref ref) => PackageInfo.fromPlatform());

final Provider<AddEntry> addEntryProvider = Provider<AddEntry>((Ref ref) {
  return AddEntry(ref.watch(entryRepositoryProvider));
});

final Provider<ChangeStatus> changeStatusProvider = Provider<ChangeStatus>((
  Ref ref,
) {
  return ChangeStatus(ref.watch(entryRepositoryProvider));
});

final Provider<SetFavorite> setFavoriteProvider = Provider<SetFavorite>((
  Ref ref,
) {
  return SetFavorite(ref.watch(entryRepositoryProvider));
});

final Provider<RemoveEntry> removeEntryProvider = Provider<RemoveEntry>((
  Ref ref,
) {
  return RemoveEntry(ref.watch(entryRepositoryProvider));
});

final Provider<ListEntries> listEntriesProvider = Provider<ListEntries>((
  Ref ref,
) {
  return ListEntries(ref.watch(entryRepositoryProvider));
});

final Provider<GroupLibrary> groupLibraryProvider = Provider<GroupLibrary>((
  Ref ref,
) {
  return const GroupLibrary();
});

final Provider<SortLibrary> sortLibraryProvider = Provider<SortLibrary>((
  Ref ref,
) {
  return const SortLibrary();
});

final Provider<FilterLibrary> filterLibraryProvider = Provider<FilterLibrary>((
  Ref ref,
) {
  return const FilterLibrary();
});
