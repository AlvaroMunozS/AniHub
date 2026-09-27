import 'package:anihub/ui/week_start.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('starts the week on Sunday in regions such as the United States', () {
    expect(firstWeekdayOfRegion('US'), DateTime.sunday);
    expect(firstWeekdayOfRegion('MX'), DateTime.sunday);
    expect(firstWeekdayOfRegion('jp'), DateTime.sunday);
  });

  test('starts the week on Monday elsewhere and without a region', () {
    expect(firstWeekdayOfRegion('ES'), DateTime.monday);
    expect(firstWeekdayOfRegion('GB'), DateTime.monday);
    expect(firstWeekdayOfRegion(null), DateTime.monday);
  });

  test('gives Monday to regions that start on Saturday', () {
    expect(firstWeekdayOfRegion('EG'), DateTime.monday);
  });
}
