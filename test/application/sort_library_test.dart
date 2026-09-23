import 'package:anihub/application/usecases/usecases.dart';
import 'package:anihub/domain/entities/entry.dart';
import 'package:anihub/domain/values/watch_status.dart';
import 'package:flutter_test/flutter_test.dart';

Entry _entry(int malId, String title, {DateTime? updatedAt}) {
  return Entry(
    malId: malId,
    title: title,
    status: WatchStatus.completed,
    updatedAt: updatedAt ?? DateTime(2024),
  );
}

LibraryGroupItem _group(int key, String label, List<Entry> members) {
  return LibraryGroupItem(key: key, label: label, members: members);
}

void main() {
  const SortLibrary sortLibrary = SortLibrary();

  test('returns the same list for recent', () {
    final List<LibraryItem> items = <LibraryItem>[
      LibraryEntryItem(_entry(2, 'B')),
      LibraryEntryItem(_entry(1, 'A')),
    ];

    final List<LibraryItem> result = sortLibrary(items, LibraryOrder.recent);

    expect(result, same(items));
  });

  test('sorts entries alphabetically ignoring case', () {
    final List<LibraryItem> items = <LibraryItem>[
      LibraryEntryItem(_entry(1, 'naruto')),
      LibraryEntryItem(_entry(2, 'Bleach')),
      LibraryEntryItem(_entry(3, 'accel world')),
    ];

    final List<LibraryItem> result = sortLibrary(
      items,
      LibraryOrder.alphabetical,
    );

    expect(
      result.map((LibraryItem i) => (i as LibraryEntryItem).entry.title),
      <String>['accel world', 'Bleach', 'naruto'],
    );
  });

  test('sorts groups by their label', () {
    final List<LibraryItem> items = <LibraryItem>[
      _group(10, 'Zeta', <Entry>[_entry(10, 'Zeta'), _entry(11, 'Zeta 2')]),
      LibraryEntryItem(_entry(1, 'Alpha')),
    ];

    final List<LibraryItem> result = sortLibrary(
      items,
      LibraryOrder.alphabetical,
    );

    expect(result[0], isA<LibraryEntryItem>());
    expect((result[0] as LibraryEntryItem).entry.title, 'Alpha');
    expect(result[1], isA<LibraryGroupItem>());
  });

  test('folds diacritics to their base letter', () {
    final List<LibraryItem> items = <LibraryItem>[
      LibraryEntryItem(_entry(1, 'Kuroko')),
      LibraryEntryItem(_entry(2, 'Kaguya')),
      LibraryEntryItem(_entry(3, 'Kōkaku')),
    ];

    final List<LibraryItem> result = sortLibrary(
      items,
      LibraryOrder.alphabetical,
    );

    expect(
      result.map((LibraryItem i) => (i as LibraryEntryItem).entry.title),
      <String>['Kaguya', 'Kōkaku', 'Kuroko'],
    );
  });

  test('breaks title ties by malId', () {
    final List<LibraryItem> items = <LibraryItem>[
      LibraryEntryItem(_entry(9, 'Same title')),
      LibraryEntryItem(_entry(2, 'Same title')),
    ];

    final List<LibraryItem> result = sortLibrary(
      items,
      LibraryOrder.alphabetical,
    );

    expect(
      result.map((LibraryItem i) => (i as LibraryEntryItem).entry.malId),
      <int>[2, 9],
    );
  });

  test('keeps the member order within groups', () {
    final List<Entry> members = <Entry>[_entry(1, 'T1'), _entry(2, 'T2')];
    final List<LibraryItem> items = <LibraryItem>[_group(1, 'T1', members)];

    final List<LibraryItem> result = sortLibrary(
      items,
      LibraryOrder.alphabetical,
    );

    final LibraryGroupItem group = result.single as LibraryGroupItem;
    expect(group.members, same(members));
  });

  test('reverses alphabetical order', () {
    final List<LibraryItem> items = <LibraryItem>[
      LibraryEntryItem(_entry(1, 'naruto')),
      LibraryEntryItem(_entry(2, 'Bleach')),
      LibraryEntryItem(_entry(3, 'accel world')),
    ];

    final List<LibraryItem> result = sortLibrary(
      items,
      LibraryOrder.alphabetical,
      reversed: true,
    );

    expect(
      result.map((LibraryItem i) => (i as LibraryEntryItem).entry.title),
      <String>['naruto', 'Bleach', 'accel world'],
    );
  });

  test('reverses recent order', () {
    final List<LibraryItem> items = <LibraryItem>[
      LibraryEntryItem(_entry(2, 'B')),
      LibraryEntryItem(_entry(1, 'A')),
    ];

    final List<LibraryItem> result = sortLibrary(
      items,
      LibraryOrder.recent,
      reversed: true,
    );

    expect(
      result.map((LibraryItem i) => (i as LibraryEntryItem).entry.malId),
      <int>[1, 2],
    );
  });
}
