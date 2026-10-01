import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart'
    show FutureProviderFamily, ProviderFamily;

import '../../application/usecases/usecases.dart';
import '../../domain/entities/catalog_anime.dart';
import '../../domain/errors/catalog_exception.dart';
import '../../domain/values/anime_season.dart';
import '../providers.dart';
import '../report_error.dart';

/// Returns the season running at [now].
YearSeason seasonAt(DateTime now) =>
    (year: now.year, season: AnimeSeason.ofMonth(now.month));

/// The anime airing in a season, as MyAnimeList lists them.
///
/// Keyed by season, so a new season is requested as soon as the view asks
/// for it, even when the app stays open across the change. Each one is kept
/// for the whole session, so returning to Browse does not request it again;
/// pulling to refresh invalidates it. A failure is not retried on its own:
/// each attempt costs several MyAnimeList requests, even after a rate limit,
/// and the view offers to retry.
final FutureProviderFamily<List<CatalogAnime>, YearSeason> airingAnimeProvider =
    FutureProvider.family<List<CatalogAnime>, YearSeason>(
      retry: (int retryCount, Object error) => null,
      (Ref ref, YearSeason season) => reportingUnexpected(
        ref.watch(animeCatalogProvider).airingIn(season.year, season.season),
        isExpected: (Object error) => error is CatalogException,
      ),
    );

/// The anime airing in a season by local weekday.
///
/// Broadcast times depend on the offset in force at the next broadcast, which
/// changes with daylight saving time and when the device changes time zone, so
/// the conversion is kept apart from the request: invalidating this provider
/// converts the cached list again without requesting it. Read it only while
/// [airingAnimeProvider] has a value.
final ProviderFamily<AiringSchedule, YearSeason> airingScheduleProvider =
    Provider.family<AiringSchedule, YearSeason>((Ref ref, YearSeason season) {
      return ref.watch(scheduleAiringProvider)(
        ref.watch(airingAnimeProvider(season)).requireValue,
        now: ref.watch(clockProvider)(),
      );
    });

/// The series that premiere in a season, finished or not, as MyAnimeList
/// lists them.
///
/// Kept for the session and not retried on its own, for the same reasons as
/// [airingAnimeProvider].
final FutureProviderFamily<List<CatalogAnime>, YearSeason>
seasonPremieresProvider = FutureProvider.family<List<CatalogAnime>, YearSeason>(
  retry: (int retryCount, Object error) => null,
  (Ref ref, YearSeason season) => reportingUnexpected(
    ref.watch(animeCatalogProvider).premieringIn(season.year, season.season),
    isExpected: (Object error) => error is CatalogException,
  ),
);

/// How many seasons Browse is from the current one: negative for past
/// seasons.
///
/// It lasts for the session. It is relative, so when the season changes while
/// the app is open, Browse moves along with it.
class BrowsedSeasonOffset extends Notifier<int> {
  /// MyAnimeList lists few series further ahead than the next season.
  static const int max = 1;

  @override
  int build() => 0;

  void previous() => state--;

  void next() {
    if (state < max) state++;
  }

  void reset() => state = 0;
}

final NotifierProvider<BrowsedSeasonOffset, int> browsedSeasonOffsetProvider =
    NotifierProvider<BrowsedSeasonOffset, int>(BrowsedSeasonOffset.new);
