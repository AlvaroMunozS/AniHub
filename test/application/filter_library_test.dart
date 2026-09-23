import 'package:anihub/application/usecases/usecases.dart';
import 'package:anihub/domain/entities/entry.dart';
import 'package:anihub/domain/values/watch_status.dart';
import 'package:flutter_test/flutter_test.dart';

Entry _entry(int malId, String title, {bool isFavorite = false}) {
  return Entry(
    malId: malId,
    title: title,
    status: WatchStatus.completed,
    updatedAt: DateTime(2024),
    isFavorite: isFavorite,
  );
}

void main() {
  const FilterLibrary filterLibrary = FilterLibrary();

  test('returns the same list when no filter is set', () {
    final List<Entry> entries = <Entry>[_entry(1, 'Naruto')];

    expect(filterLibrary(entries), same(entries));
  });

  test('does not filter on a blank query', () {
    final List<Entry> entries = <Entry>[_entry(1, 'Naruto')];

    expect(filterLibrary(entries, query: '   '), same(entries));
  });

  test('matches ignoring case and diacritics', () {
    final List<Entry> entries = <Entry>[
      _entry(1, 'Kōkaku Kidōtai'),
      _entry(2, 'Naruto'),
    ];

    final List<Entry> result = filterLibrary(entries, query: 'kokaku');

    expect(result.map((Entry e) => e.malId), <int>[1]);
  });

  test('matches the query anywhere in the title', () {
    final List<Entry> entries = <Entry>[
      _entry(1, 'Sousou no Frieren'),
      _entry(2, 'Naruto'),
    ];

    final List<Entry> result = filterLibrary(entries, query: 'frieren');

    expect(result.map((Entry e) => e.malId), <int>[1]);
  });

  test('keeps only favorites when favorites is only', () {
    final List<Entry> entries = <Entry>[
      _entry(1, 'Naruto', isFavorite: true),
      _entry(2, 'Bleach'),
    ];

    final List<Entry> result = filterLibrary(
      entries,
      favorites: FilterMode.only,
    );

    expect(result.map((Entry e) => e.malId), <int>[1]);
  });

  test('hides favorites when favorites is exclude', () {
    final List<Entry> entries = <Entry>[
      _entry(1, 'Naruto', isFavorite: true),
      _entry(2, 'Bleach'),
    ];

    final List<Entry> result = filterLibrary(
      entries,
      favorites: FilterMode.exclude,
    );

    expect(result.map((Entry e) => e.malId), <int>[2]);
  });

  test('keeps only entries missing from started when notStarted is only', () {
    final List<Entry> entries = <Entry>[
      _entry(1, 'Naruto'),
      _entry(2, 'Bleach'),
    ];

    final List<Entry> result = filterLibrary(
      entries,
      notStarted: FilterMode.only,
      started: <int>{1},
    );

    expect(result.map((Entry e) => e.malId), <int>[2]);
  });

  test('keeps only started entries when notStarted is exclude', () {
    final List<Entry> entries = <Entry>[
      _entry(1, 'Naruto'),
      _entry(2, 'Bleach'),
    ];

    final List<Entry> result = filterLibrary(
      entries,
      notStarted: FilterMode.exclude,
      started: <int>{1},
    );

    expect(result.map((Entry e) => e.malId), <int>[1]);
  });

  test('ignores started when notStarted is any', () {
    final List<Entry> entries = <Entry>[
      _entry(1, 'Naruto'),
      _entry(2, 'Bleach'),
    ];

    expect(filterLibrary(entries, started: <int>{1}), same(entries));
  });

  test('requires the query and every filter to match', () {
    final List<Entry> entries = <Entry>[
      _entry(1, 'Naruto', isFavorite: true),
      _entry(2, 'Naruto Shippuden'),
      _entry(3, 'Bleach', isFavorite: true),
      _entry(4, 'Naruto the Movie', isFavorite: true),
    ];

    final List<Entry> result = filterLibrary(
      entries,
      query: 'naruto',
      favorites: FilterMode.only,
      notStarted: FilterMode.only,
      started: <int>{4},
    );

    expect(result.map((Entry e) => e.malId), <int>[1]);
  });

  test('returns an empty list when nothing matches', () {
    final List<Entry> entries = <Entry>[_entry(1, 'Naruto')];

    expect(filterLibrary(entries, query: 'no match'), isEmpty);
  });
}
