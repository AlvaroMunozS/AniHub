import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/usecases/usecases.dart';
import '../../domain/entities/catalog_anime.dart';
import '../../domain/errors/catalog_exception.dart';
import '../../domain/values/anime_season.dart';
import '../providers.dart';
import '../report_error.dart';

/// The season running now, with its year.
final Provider<({int year, AnimeSeason season})> currentSeasonProvider =
    Provider<({int year, AnimeSeason season})>((Ref ref) {
      final DateTime now = ref.watch(clockProvider)();
      return (year: now.year, season: AnimeSeason.ofMonth(now.month));
    });

/// The anime airing this season by weekday.
///
/// Kept for the whole session, so returning to Browse does not request it
/// again; pulling to refresh invalidates it.
final FutureProvider<AiringSchedule> airingScheduleProvider =
    FutureProvider<AiringSchedule>((Ref ref) async {
      final ({int year, AnimeSeason season}) current = ref.watch(
        currentSeasonProvider,
      );
      final List<CatalogAnime> anime = await reportingUnexpected(
        ref.watch(animeCatalogProvider).airingIn(current.year, current.season),
        isExpected: (Object error) => error is CatalogException,
      );
      return ref.read(scheduleAiringProvider)(
        anime,
        now: ref.read(clockProvider)(),
      );
    });
