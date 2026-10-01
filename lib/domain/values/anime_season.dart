/// Release season of an anime.
enum AnimeSeason {
  winter,
  spring,
  summer,
  fall;

  /// Returns the season that [month], from 1 to 12, falls in: MyAnimeList
  /// counts winter from January to March, and so on in quarters.
  static AnimeSeason ofMonth(int month) {
    RangeError.checkValueInInterval(month, 1, 12, 'month');
    return values[(month - 1) ~/ 3];
  }
}

/// A season with its year.
typedef YearSeason = ({int year, AnimeSeason season});

extension YearSeasonSteps on YearSeason {
  /// Returns the season [count] seasons after this one, or before it when
  /// [count] is negative.
  YearSeason shifted(int count) {
    final int perYear = AnimeSeason.values.length;
    final int index = year * perYear + season.index + count;
    return (
      year: index ~/ perYear,
      season: AnimeSeason.values[index % perYear],
    );
  }
}
