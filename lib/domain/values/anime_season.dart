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
