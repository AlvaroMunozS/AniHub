import 'package:anihub/domain/values/release_date.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('has no sort key without a year', () {
    expect(const ReleaseDate(month: 4, day: 1).sortKey, isNull);
  });

  test('orders full dates chronologically', () {
    const ReleaseDate earlier = ReleaseDate(year: 2023, month: 9, day: 29);
    const ReleaseDate later = ReleaseDate(year: 2023, month: 10, day: 6);

    expect(earlier.sortKey!, lessThan(later.sortKey!));
  });

  test('orders a partial date before a full one in the same year', () {
    const ReleaseDate yearOnly = ReleaseDate(year: 2023);
    const ReleaseDate yearAndMonth = ReleaseDate(year: 2023, month: 1);
    const ReleaseDate full = ReleaseDate(year: 2023, month: 1, day: 1);

    expect(yearOnly.sortKey!, lessThan(yearAndMonth.sortKey!));
    expect(yearAndMonth.sortKey!, lessThan(full.sortKey!));
  });

  test('orders any date of a year before any date of the next', () {
    const ReleaseDate endOfYear = ReleaseDate(year: 2022, month: 12, day: 31);
    const ReleaseDate nextYear = ReleaseDate(year: 2023);

    expect(endOfYear.sortKey!, lessThan(nextYear.sortKey!));
  });
}
