import 'package:anihub/domain/values/broadcast.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Broadcast.nextAfter', () {
    // Thursday 24 September 2026 at noon UTC = 21:00 JST.
    final DateTime now = DateTime.utc(2026, 9, 24, 12);

    test('returns the next slot as a UTC instant', () {
      const Broadcast friday = Broadcast(
        weekday: DateTime.friday,
        hour: 23,
        minute: 0,
      );
      expect(friday.nextAfter(now), DateTime.utc(2026, 9, 25, 14));
    });

    test('a slot that already aired today is next week', () {
      const Broadcast thursday = Broadcast(
        weekday: DateTime.thursday,
        hour: 20,
        minute: 0,
      );
      expect(thursday.nextAfter(now), DateTime.utc(2026, 10, 1, 11));
    });

    test('a slot exactly at the instant counts as the next week', () {
      const Broadcast thursday = Broadcast(
        weekday: DateTime.thursday,
        hour: 21,
        minute: 0,
      );
      expect(thursday.nextAfter(now), DateTime.utc(2026, 10, 1, 12));
    });

    test('crosses the end of the year', () {
      const Broadcast friday = Broadcast(
        weekday: DateTime.friday,
        hour: 0,
        minute: 30,
      );
      // Thursday 31 Dec 2026 10:00 UTC = 19:00 JST; next Friday 00:30 JST is
      // 1 Jan 2027 00:30 JST = 31 Dec 2026 15:30 UTC.
      expect(
        friday.nextAfter(DateTime.utc(2026, 12, 31, 10)),
        DateTime.utc(2026, 12, 31, 15, 30),
      );
    });

    test('returns null when only the day is known', () {
      expect(const Broadcast(weekday: DateTime.monday).nextAfter(now), isNull);
    });
  });
}
