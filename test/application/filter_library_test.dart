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

  test('keeps only favorites when onlyFavorites is set', () {
    final List<Entry> entries = <Entry>[
      _entry(1, 'Naruto', isFavorite: true),
      _entry(2, 'Bleach'),
    ];

    final List<Entry> result = filterLibrary(entries, onlyFavorites: true);

    expect(result.map((Entry e) => e.malId), <int>[1]);
  });

  test('requires both the query and onlyFavorites to match', () {
    final List<Entry> entries = <Entry>[
      _entry(1, 'Naruto', isFavorite: true),
      _entry(2, 'Naruto Shippuden'),
      _entry(3, 'Bleach', isFavorite: true),
    ];

    final List<Entry> result = filterLibrary(
      entries,
      query: 'naruto',
      onlyFavorites: true,
    );

    expect(result.map((Entry e) => e.malId), <int>[1]);
  });

  test('returns an empty list when nothing matches', () {
    final List<Entry> entries = <Entry>[_entry(1, 'Naruto')];

    expect(filterLibrary(entries, query: 'no match'), isEmpty);
  });
}
