import 'package:anihub/application/usecases/usecases.dart';
import 'package:anihub/domain/entities/catalog_anime.dart';
import 'package:anihub/domain/values/release_date.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ten weekly episodes from Saturday 25 July 2026, the last one on Saturday
/// 26 September, as MyAnimeList gives Bleach's Kashin-tan.
CatalogAnime _anime({
  ReleaseDate? start = const ReleaseDate(year: 2026, month: 7, day: 25),
  int? episodes = 10,
}) => CatalogAnime(
  malId: 60636,
  title: 'Bleach: Sennen Kessen-hen - Kashin-tan',
  isAiring: true,
  startDate: start,
  totalEpisodes: episodes,
);

/// Midnight in Japan at the end of 10 October 2026, two weeks after the day
/// of the last episode.
final DateTime _twoWeeksAfterLast = DateTime.utc(2026, 10, 10, 15);

void main() {
  test('ends two weeks after the day of the last weekly episode', () {
    expect(hasEnded(_anime(), now: _twoWeeksAfterLast), isTrue);
  });

  test('still airs a minute before those two weeks are over', () {
    expect(
      hasEnded(
        _anime(),
        now: _twoWeeksAfterLast.subtract(const Duration(minutes: 1)),
      ),
      isFalse,
    );
  });

  test('ends a one-episode series two weeks after the day it aired', () {
    final CatalogAnime special = _anime(episodes: 1);

    expect(hasEnded(special, now: DateTime.utc(2026, 8, 8, 15)), isTrue);
    expect(hasEnded(special, now: DateTime.utc(2026, 8, 8, 14, 59)), isFalse);
  });

  test('still airs before it starts', () {
    expect(hasEnded(_anime(), now: DateTime.utc(2026, 7, 20)), isFalse);
  });

  test('still airs without an episode count', () {
    expect(hasEnded(_anime(episodes: null), now: DateTime.utc(2030)), isFalse);
  });

  test('still airs without the day it started', () {
    expect(
      hasEnded(
        _anime(start: const ReleaseDate(year: 2026, month: 7)),
        now: DateTime.utc(2030),
      ),
      isFalse,
    );
  });
}
