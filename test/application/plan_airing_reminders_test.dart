import 'package:anihub/application/usecases/usecases.dart';
import 'package:anihub/domain/entities/catalog_anime.dart';
import 'package:anihub/domain/values/airing_reminder.dart';
import 'package:anihub/domain/values/broadcast.dart';
import 'package:anihub/domain/values/release_date.dart';
import 'package:flutter_test/flutter_test.dart';

/// Thursday 24 September 2026 at noon UTC.
final DateTime _now = DateTime.utc(2026, 9, 24, 12);

const PlanAiringReminders plan = PlanAiringReminders();
const Broadcast friday23 = Broadcast(
  weekday: DateTime.friday,
  hour: 23,
  minute: 0,
);

CatalogAnime _anime(
  int id,
  String title, {
  Broadcast? broadcast,
  bool isAiring = true,
  ReleaseDate? start,
  int? members,
}) => CatalogAnime(
  malId: id,
  title: title,
  broadcast: broadcast,
  isAiring: isAiring,
  startDate: start,
  memberCount: members,
);

void main() {
  test('reminds each broadcast in the next two weeks of a watched series', () {
    final List<AiringReminder> reminders = plan(
      <CatalogAnime>[_anime(1, 'Frieren', broadcast: friday23)],
      watching: <int>{1},
      now: _now,
    );

    expect(reminders, <AiringReminder>[
      AiringReminder(
        malId: 1,
        title: 'Frieren',
        at: DateTime.utc(2026, 9, 25, 14),
      ),
      AiringReminder(
        malId: 1,
        title: 'Frieren',
        at: DateTime.utc(2026, 10, 2, 14),
      ),
    ]);
  });

  test('includes a broadcast exactly at the end of the horizon', () {
    // Thursday 12:00 UTC is 21:00 in Japan, so the slot two weeks ahead falls
    // exactly on the end of the horizon.
    const Broadcast thursday21 = Broadcast(
      weekday: DateTime.thursday,
      hour: 21,
      minute: 0,
    );

    final List<AiringReminder> reminders = plan(
      <CatalogAnime>[_anime(1, 'A', broadcast: thursday21)],
      watching: <int>{1},
      now: _now,
    );

    expect(reminders.map((AiringReminder r) => r.at), <DateTime>[
      DateTime.utc(2026, 10, 1, 12),
      DateTime.utc(2026, 10, 8, 12),
    ]);
  });

  test('leaves out series not being watched', () {
    final List<AiringReminder> reminders = plan(
      <CatalogAnime>[_anime(1, 'Frieren', broadcast: friday23)],
      watching: <int>{},
      now: _now,
    );

    expect(reminders, isEmpty);
  });

  test('leaves out series without a broadcast time', () {
    final List<AiringReminder> reminders = plan(
      <CatalogAnime>[
        _anime(
          1,
          'Frieren',
          broadcast: const Broadcast(weekday: DateTime.friday),
        ),
      ],
      watching: <int>{1},
      now: _now,
    );

    expect(reminders, isEmpty);
  });

  test('reminds niche series too', () {
    final List<AiringReminder> reminders = plan(
      <CatalogAnime>[_anime(1, 'Niche', broadcast: friday23, members: 10)],
      watching: <int>{1},
      now: _now,
    );

    expect(reminders, hasLength(2));
  });

  test('reminds a series that has not aired yet only from its premiere', () {
    final List<AiringReminder> reminders = plan(
      <CatalogAnime>[
        _anime(
          1,
          'New',
          broadcast: friday23,
          isAiring: false,
          start: const ReleaseDate(year: 2026, month: 10, day: 2),
        ),
      ],
      watching: <int>{1},
      now: _now,
    );

    expect(reminders.map((AiringReminder r) => r.at), <DateTime>[
      DateTime.utc(2026, 10, 2, 14),
    ]);
  });

  test('includes the premiere day from its first minute in Japan', () {
    const Broadcast thursday2330 = Broadcast(
      weekday: DateTime.thursday,
      hour: 23,
      minute: 30,
    );
    const Broadcast friday0030 = Broadcast(
      weekday: DateTime.friday,
      hour: 0,
      minute: 30,
    );
    const ReleaseDate premiere = ReleaseDate(year: 2026, month: 10, day: 2);

    final List<AiringReminder> reminders = plan(
      <CatalogAnime>[
        _anime(
          1,
          'Day before',
          broadcast: thursday2330,
          isAiring: false,
          start: premiere,
        ),
        _anime(
          2,
          'Premiere day',
          broadcast: friday0030,
          isAiring: false,
          start: premiere,
        ),
      ],
      watching: <int>{1, 2},
      now: _now,
    );

    expect(
      reminders.map((AiringReminder r) => (r.malId, r.at)),
      <(int, DateTime)>[(2, DateTime.utc(2026, 10, 1, 15, 30))],
    );
  });

  test('waits for a full premiere date before reminding a series that has not '
      'aired', () {
    final List<AiringReminder> monthOnly = plan(
      <CatalogAnime>[
        _anime(
          1,
          'New',
          broadcast: friday23,
          isAiring: false,
          start: const ReleaseDate(year: 2026, month: 10),
        ),
      ],
      watching: <int>{1},
      now: _now,
    );
    final List<AiringReminder> noDate = plan(
      <CatalogAnime>[_anime(1, 'New', broadcast: friday23, isAiring: false)],
      watching: <int>{1},
      now: _now,
    );

    expect(monthOnly, isEmpty);
    expect(noDate, isEmpty);
  });

  test('orders reminders by time', () {
    const Broadcast friday20 = Broadcast(
      weekday: DateTime.friday,
      hour: 20,
      minute: 0,
    );
    const Broadcast saturday1 = Broadcast(
      weekday: DateTime.saturday,
      hour: 1,
      minute: 0,
    );

    final List<AiringReminder> reminders = plan(
      <CatalogAnime>[
        _anime(1, 'Late', broadcast: friday23),
        _anime(2, 'Early', broadcast: friday20),
        _anime(3, 'Night', broadcast: saturday1),
      ],
      watching: <int>{1, 2, 3},
      now: _now,
    );

    expect(
      reminders.map((AiringReminder r) => (r.malId, r.at)),
      <(int, DateTime)>[
        (2, DateTime.utc(2026, 9, 25, 11)),
        (1, DateTime.utc(2026, 9, 25, 14)),
        (3, DateTime.utc(2026, 9, 25, 16)),
        (2, DateTime.utc(2026, 10, 2, 11)),
        (1, DateTime.utc(2026, 10, 2, 14)),
        (3, DateTime.utc(2026, 10, 2, 16)),
      ],
    );
  });
}
