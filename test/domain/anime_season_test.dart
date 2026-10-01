import 'package:anihub/domain/values/anime_season.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('counts the seasons in quarters from January', () {
    expect(AnimeSeason.ofMonth(1), AnimeSeason.winter);
    expect(AnimeSeason.ofMonth(3), AnimeSeason.winter);
    expect(AnimeSeason.ofMonth(4), AnimeSeason.spring);
    expect(AnimeSeason.ofMonth(6), AnimeSeason.spring);
    expect(AnimeSeason.ofMonth(7), AnimeSeason.summer);
    expect(AnimeSeason.ofMonth(9), AnimeSeason.summer);
    expect(AnimeSeason.ofMonth(10), AnimeSeason.fall);
    expect(AnimeSeason.ofMonth(12), AnimeSeason.fall);
  });

  test('rejects a month outside 1 to 12', () {
    expect(() => AnimeSeason.ofMonth(0), throwsRangeError);
    expect(() => AnimeSeason.ofMonth(13), throwsRangeError);
  });

  test('steps forward and back across the year', () {
    const YearSeason fall = (year: 2026, season: AnimeSeason.fall);
    const YearSeason winter = (year: 2026, season: AnimeSeason.winter);

    expect(fall.shifted(1), (year: 2027, season: AnimeSeason.winter));
    expect(winter.shifted(-1), (year: 2025, season: AnimeSeason.fall));
    expect(fall.shifted(-5), (year: 2025, season: AnimeSeason.summer));
    expect(fall.shifted(0), fall);
  });
}
