import 'package:anihub/application/usecases/usecases.dart';
import 'package:anihub/domain/entities/catalog_anime.dart';
import 'package:anihub/domain/values/broadcast.dart';
import 'package:flutter_test/flutter_test.dart';

/// Thursday 24 September 2026 at noon UTC.
final DateTime _now = DateTime.utc(2026, 9, 24, 12);

CatalogAnime _anime(
  int id,
  String title, [
  Broadcast? broadcast,
  int? members,
]) => CatalogAnime(
  malId: id,
  title: title,
  broadcast: broadcast,
  memberCount: members,
);

ScheduleAiring _at(Duration offset) =>
    ScheduleAiring(localOffset: (DateTime utc) => offset);

List<String> _titles(List<ScheduledAnime>? day) => <String>[
  for (final ScheduledAnime item in day ?? const <ScheduledAnime>[])
    item.anime.title,
];

void main() {
  test('converts a slot from Japan to local time on the same day', () {
    final AiringSchedule schedule = _at(const Duration(hours: 2))(
      <CatalogAnime>[
        _anime(
          1,
          'Frieren',
          const Broadcast(weekday: DateTime.friday, hour: 23, minute: 0),
        ),
      ],
      now: _now,
    );

    final ScheduledAnime item = schedule.byWeekday[DateTime.friday]!.single;
    expect((item.hour, item.minute), (16, 0));
  });

  test('moves a late-night slot in Japan to the previous local day', () {
    final CatalogAnime lateNight = _anime(
      1,
      'Kaiju',
      const Broadcast(weekday: DateTime.monday, hour: 0, minute: 30),
    );

    final AiringSchedule madrid = _at(const Duration(hours: 2))(<CatalogAnime>[
      lateNight,
    ], now: _now);
    final AiringSchedule newYork = _at(const Duration(hours: -4))(
      <CatalogAnime>[lateNight],
      now: _now,
    );

    final ScheduledAnime inMadrid = madrid.byWeekday[DateTime.sunday]!.single;
    expect((inMadrid.hour, inMadrid.minute), (17, 30));
    final ScheduledAnime inNewYork = newYork.byWeekday[DateTime.sunday]!.single;
    expect((inNewYork.hour, inNewYork.minute), (11, 30));
    expect(madrid.byWeekday.containsKey(DateTime.monday), isFalse);
  });

  test('uses the offset in force in the week of the broadcast', () {
    final List<DateTime> asked = <DateTime>[];
    ScheduleAiring(
      localOffset: (DateTime utc) {
        asked.add(utc);
        return Duration.zero;
      },
    )(<CatalogAnime>[
      _anime(
        1,
        'Frieren',
        const Broadcast(weekday: DateTime.saturday, hour: 1, minute: 0),
      ),
    ], now: _now);

    expect(asked, <DateTime>[DateTime.utc(2026, 9, 25, 16)]);
  });

  test(
    'converts a slot after a daylight saving change with the new offset',
    () {
      // Madrid leaves summer time on 25 October 2026 at 01:00 UTC.
      final ScheduleAiring madrid = ScheduleAiring(
        localOffset: (DateTime utc) =>
            utc.isBefore(DateTime.utc(2026, 10, 25, 1))
            ? const Duration(hours: 2)
            : const Duration(hours: 1),
      );

      final AiringSchedule schedule = madrid(<CatalogAnime>[
        _anime(
          1,
          'Kaiju',
          const Broadcast(weekday: DateTime.monday, hour: 0, minute: 30),
        ),
      ], now: DateTime.utc(2026, 10, 22, 12));

      final ScheduledAnime item = schedule.byWeekday[DateTime.sunday]!.single;
      expect((item.hour, item.minute), (16, 30));
    },
  );

  test('rolls a slot that has passed today to next week', () {
    // It is 21:00 in Japan on Thursday, an hour after the slot.
    final List<DateTime> asked = <DateTime>[];
    ScheduleAiring(
      localOffset: (DateTime utc) {
        asked.add(utc);
        return Duration.zero;
      },
    )(<CatalogAnime>[
      _anime(
        1,
        'Frieren',
        const Broadcast(weekday: DateTime.thursday, hour: 20, minute: 0),
      ),
    ], now: _now);

    expect(asked, <DateTime>[DateTime.utc(2026, 10, 1, 11)]);
  });

  test('rolls a slot that airs at this very instant to next week', () {
    final List<DateTime> asked = <DateTime>[];
    ScheduleAiring(
      localOffset: (DateTime utc) {
        asked.add(utc);
        return Duration.zero;
      },
    )(<CatalogAnime>[
      _anime(
        1,
        'Frieren',
        const Broadcast(weekday: DateTime.thursday, hour: 20, minute: 0),
      ),
    ], now: DateTime.utc(2026, 9, 24, 11));

    expect(asked, <DateTime>[DateTime.utc(2026, 10, 1, 11)]);
  });

  test('uses next week\'s offset for a slot that has passed today', () {
    // It is 21:00 in Japan on Saturday 24 October; Madrid changes its clocks
    // that night.
    final ScheduleAiring madrid = ScheduleAiring(
      localOffset: (DateTime utc) => utc.isBefore(DateTime.utc(2026, 10, 25, 1))
          ? const Duration(hours: 2)
          : const Duration(hours: 1),
    );

    final AiringSchedule schedule = madrid(<CatalogAnime>[
      _anime(
        1,
        'Frieren',
        const Broadcast(weekday: DateTime.saturday, hour: 20, minute: 0),
      ),
    ], now: DateTime.utc(2026, 10, 24, 12));

    final ScheduledAnime item = schedule.byWeekday[DateTime.saturday]!.single;
    expect((item.hour, item.minute), (12, 0));
  });

  test('looks ahead to a weekday later in the week, never back', () {
    final List<DateTime> asked = <DateTime>[];
    ScheduleAiring(
      localOffset: (DateTime utc) {
        asked.add(utc);
        return Duration.zero;
      },
    )(<CatalogAnime>[
      _anime(
        1,
        'Frieren',
        const Broadcast(weekday: DateTime.tuesday, hour: 20, minute: 0),
      ),
    ], now: _now);

    expect(asked, <DateTime>[DateTime.utc(2026, 9, 29, 11)]);
  });

  test('orders each day by members, then by title, unknown counts last', () {
    const Broadcast sunday = Broadcast(
      weekday: DateTime.sunday,
      hour: 20,
      minute: 0,
    );
    final AiringSchedule schedule = _at(Duration.zero)(<CatalogAnime>[
      _anime(1, 'Unknown', sunday),
      _anime(2, 'Zeta', sunday, 6000),
      _anime(3, 'Re:Zero', sunday, 334883),
      _anime(4, 'Beta', sunday, 6000),
    ], now: _now);

    expect(_titles(schedule.byWeekday[DateTime.sunday]), <String>[
      'Re:Zero',
      'Beta',
      'Zeta',
      'Unknown',
    ]);
  });

  test('leaves out anime in too few lists', () {
    const Broadcast monday = Broadcast(weekday: DateTime.monday);
    final AiringSchedule schedule = _at(Duration.zero)(<CatalogAnime>[
      _anime(1, 'Niche', monday, ScheduleAiring.minMembers - 1),
      _anime(2, 'Known', monday, ScheduleAiring.minMembers),
    ], now: _now);

    expect(_titles(schedule.byWeekday[DateTime.monday]), <String>['Known']);
  });

  test('keeps the day in Japan when the time is unknown', () {
    final AiringSchedule schedule = _at(const Duration(hours: -4))(
      <CatalogAnime>[
        _anime(1, 'Kaiju', const Broadcast(weekday: DateTime.monday)),
      ],
      now: _now,
    );

    final ScheduledAnime item = schedule.byWeekday[DateTime.monday]!.single;
    expect(item.hour, isNull);
  });

  test('leaves out anime without a weekly slot', () {
    final AiringSchedule schedule = _at(Duration.zero)(<CatalogAnime>[
      _anime(1, 'Alpha', null, 9000),
      _anime(
        2,
        'Frieren',
        const Broadcast(weekday: DateTime.friday, hour: 23, minute: 0),
      ),
    ], now: _now);

    expect(_titles(schedule.byWeekday[DateTime.friday]), <String>['Frieren']);
    expect(schedule.length, 1);
  });

  test('keeps the given anime even in too few lists', () {
    const Broadcast monday = Broadcast(weekday: DateTime.monday);
    final AiringSchedule schedule = _at(Duration.zero)(
      <CatalogAnime>[
        _anime(1, 'Followed', monday, ScheduleAiring.minMembers - 1),
        _anime(2, 'Niche', monday, ScheduleAiring.minMembers - 1),
      ],
      now: _now,
      keep: <int>{1},
    );

    expect(_titles(schedule.byWeekday[DateTime.monday]), <String>['Followed']);
  });

  test('leaves out a kept anime without a weekly slot', () {
    final AiringSchedule schedule = _at(Duration.zero)(
      <CatalogAnime>[_anime(1, 'Alpha', null, 9000)],
      now: _now,
      keep: <int>{1},
    );

    expect(schedule.isEmpty, isTrue);
  });

  test('only keeps the given anime and drops the days left empty', () {
    final AiringSchedule schedule = _at(Duration.zero)(<CatalogAnime>[
      _anime(1, 'Mine', const Broadcast(weekday: DateTime.monday), 9000),
      _anime(2, 'Theirs', const Broadcast(weekday: DateTime.monday), 9000),
      _anime(3, 'Elsewhere', const Broadcast(weekday: DateTime.tuesday), 9000),
    ], now: _now).only(<int>{1});

    expect(_titles(schedule.byWeekday[DateTime.monday]), <String>['Mine']);
    expect(schedule.byWeekday.containsKey(DateTime.tuesday), isFalse);
    expect(schedule.length, 1);
  });

  test('only orders each day by time, unknown times last, ties by members', () {
    // With no offset, these Sunday evening slots in Japan stay on Sunday.
    Broadcast sunday(int hour) =>
        Broadcast(weekday: DateTime.sunday, hour: hour, minute: 0);
    final AiringSchedule schedule = _at(Duration.zero)(<CatalogAnime>[
      _anime(1, 'Late', sunday(22), 900000),
      _anime(2, 'No time', const Broadcast(weekday: DateTime.sunday), 900000),
      _anime(3, 'Early, less followed', sunday(18), 6000),
      _anime(4, 'Early, more followed', sunday(18), 80000),
    ], now: _now).only(<int>{1, 2, 3, 4});

    expect(_titles(schedule.byWeekday[DateTime.sunday]), <String>[
      'Early, more followed',
      'Early, less followed',
      'Late',
      'No time',
    ]);
  });
}
