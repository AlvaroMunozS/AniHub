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
    final AiringSchedule schedule = _at(Duration.zero)(<CatalogAnime>[
      _anime(1, 'Niche', null, ScheduleAiring.minMembers - 1),
      _anime(2, 'Known', null, ScheduleAiring.minMembers),
    ], now: _now);

    expect(schedule.unscheduled.map((CatalogAnime a) => a.title), <String>[
      'Known',
    ]);
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

  test('lists anime without a slot apart, by title', () {
    final AiringSchedule schedule = _at(Duration.zero)(<CatalogAnime>[
      _anime(1, 'Zeta'),
      _anime(
        2,
        'Frieren',
        const Broadcast(weekday: DateTime.friday, hour: 23, minute: 0),
      ),
      _anime(3, 'Alpha'),
    ], now: _now);

    expect(schedule.unscheduled.map((CatalogAnime a) => a.title), <String>[
      'Alpha',
      'Zeta',
    ]);
    expect(schedule.length, 3);
  });
}
