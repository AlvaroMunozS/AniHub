import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;

import '../../application/usecases/usecases.dart';
import '../../domain/entities/catalog_anime.dart';
import '../../domain/errors/catalog_exception.dart';
import '../../domain/values/anime_season.dart';
import '../providers.dart';
import '../report_error.dart';

/// A season with its year.
typedef AiringSeason = ({int year, AnimeSeason season});

/// Returns the season running at [now].
AiringSeason seasonAt(DateTime now) =>
    (year: now.year, season: AnimeSeason.ofMonth(now.month));

/// The anime airing in a season by weekday.
///
/// Keyed by season, so a new season is requested as soon as the view asks
/// for it, even when the app stays open across the change. Each one is kept
/// for the whole session, so returning to Browse does not request it again;
/// pulling to refresh invalidates it. A failure is not retried on its own:
/// each attempt costs several MyAnimeList requests, even after a rate limit,
/// and the view offers to retry.
final FutureProviderFamily<AiringSchedule, AiringSeason>
airingScheduleProvider = FutureProvider.family<AiringSchedule, AiringSeason>(
  retry: (int retryCount, Object error) => null,
  (Ref ref, AiringSeason season) async {
    final List<CatalogAnime> anime = await reportingUnexpected(
      ref.watch(animeCatalogProvider).airingIn(season.year, season.season),
      isExpected: (Object error) => error is CatalogException,
    );
    return ref.read(scheduleAiringProvider)(
      anime,
      now: ref.read(clockProvider)(),
    );
  },
);
