import '../../domain/entities/catalog_anime.dart';
import 'relevance.dart';
import 'schedule_airing.dart';

/// Ranks the series that premiere in a season, most followed first.
///
/// Anime in fewer than [ScheduleAiring.minMembers] MyAnimeList lists are left
/// out, as in the airing schedule. The next season ([upcoming]) has not aired
/// yet, so even its best-known series are in fewer lists, and
/// [upcomingMinMembers] applies instead. Anime whose count is unknown are
/// listed.
class RankSeason {
  const RankSeason();

  /// Fewest lists a series of the next season must be in to be listed.
  static const int upcomingMinMembers = 1000;

  List<CatalogAnime> call(List<CatalogAnime> anime, {required bool upcoming}) {
    final int minMembers = upcoming
        ? upcomingMinMembers
        : ScheduleAiring.minMembers;
    final List<CatalogAnime> ranked = <CatalogAnime>[
      for (final CatalogAnime item in anime)
        if ((item.memberCount ?? minMembers) >= minMembers) item,
    ]..sort(compareRelevance);
    return List<CatalogAnime>.unmodifiable(ranked);
  }
}
