import 'package:anihub/application/usecases/usecases.dart';
import 'package:anihub/domain/entities/anime_relation.dart';
import 'package:anihub/domain/entities/anime_relation_node.dart';
import 'package:anihub/domain/entities/entry.dart';
import 'package:anihub/domain/values/relation_kind.dart';
import 'package:anihub/domain/values/release_date.dart';
import 'package:anihub/domain/values/watch_status.dart';
import 'package:flutter_test/flutter_test.dart';

Entry _entry(
  int malId,
  String title, {
  required DateTime updatedAt,
  WatchStatus status = WatchStatus.completed,
}) {
  return Entry(
    malId: malId,
    title: title,
    status: status,
    updatedAt: updatedAt,
  );
}

AnimeRelation _relation(int malId, RelationKind kind, {String title = 'x'}) {
  return AnimeRelation(malId: malId, kind: kind, title: title);
}

void main() {
  const GroupLibrary groupLibrary = GroupLibrary();
  final DateTime base = DateTime(2024);

  test('groups seasons 1 and 3 through a missing season 2', () {
    // 1 -> 2 -> 3, where 2 is not in the library.
    final Map<int, AnimeRelationNode> relations = <int, AnimeRelationNode>{
      1: AnimeRelationNode(
        malId: 1,
        title: 'Season 1',
        startDate: const ReleaseDate(year: 2010),
        relations: <AnimeRelation>[_relation(2, RelationKind.sequel)],
      ),
      2: AnimeRelationNode(
        malId: 2,
        title: 'Season 2',
        startDate: const ReleaseDate(year: 2012),
        relations: <AnimeRelation>[
          _relation(1, RelationKind.prequel),
          _relation(3, RelationKind.sequel),
        ],
      ),
      3: AnimeRelationNode(
        malId: 3,
        title: 'Season 3',
        startDate: const ReleaseDate(year: 2014),
        relations: <AnimeRelation>[_relation(2, RelationKind.prequel)],
      ),
    };
    final List<Entry> entries = <Entry>[
      _entry(3, 'Season 3', updatedAt: base),
      _entry(1, 'Season 1', updatedAt: base.subtract(const Duration(days: 1))),
    ];

    final List<LibraryItem> result = groupLibrary(entries, relations);

    expect(result, hasLength(1));
    final LibraryGroupItem group = result.single as LibraryGroupItem;
    expect(group.members.map((Entry e) => e.malId), <int>[1, 3]);
  });

  test('does not group through character or other edges', () {
    final Map<int, AnimeRelationNode> relations = <int, AnimeRelationNode>{
      1: AnimeRelationNode(
        malId: 1,
        title: 'A',
        relations: <AnimeRelation>[_relation(2, RelationKind.character)],
      ),
      2: AnimeRelationNode(
        malId: 2,
        title: 'B',
        relations: <AnimeRelation>[_relation(1, RelationKind.other)],
      ),
    };
    final List<Entry> entries = <Entry>[
      _entry(1, 'A', updatedAt: base),
      _entry(2, 'B', updatedAt: base.subtract(const Duration(days: 1))),
    ];

    final List<LibraryItem> result = groupLibrary(entries, relations);

    expect(result, hasLength(2));
    expect(result.every((LibraryItem i) => i is LibraryEntryItem), isTrue);
  });

  test('does not form a group with a single library member', () {
    final Map<int, AnimeRelationNode> relations = <int, AnimeRelationNode>{
      1: AnimeRelationNode(
        malId: 1,
        title: 'A',
        relations: <AnimeRelation>[_relation(2, RelationKind.sequel)],
      ),
    };
    final List<Entry> entries = <Entry>[
      _entry(1, 'A', updatedAt: base),
      _entry(
        9,
        'Standalone',
        updatedAt: base.subtract(const Duration(days: 1)),
      ),
    ];

    final List<LibraryItem> result = groupLibrary(entries, relations);

    expect(result, hasLength(2));
    expect(result[0], isA<LibraryEntryItem>());
    expect((result[0] as LibraryEntryItem).entry.malId, 1);
  });

  test('orders members by start date', () {
    final Map<int, AnimeRelationNode> relations = <int, AnimeRelationNode>{
      1: AnimeRelationNode(
        malId: 1,
        title: 'T1',
        startDate: const ReleaseDate(year: 2020),
        relations: <AnimeRelation>[_relation(2, RelationKind.sequel)],
      ),
      2: AnimeRelationNode(
        malId: 2,
        title: 'T2',
        startDate: const ReleaseDate(year: 2010),
        relations: <AnimeRelation>[_relation(1, RelationKind.prequel)],
      ),
    };
    final List<Entry> entries = <Entry>[
      _entry(1, 'T1', updatedAt: base),
      _entry(2, 'T2', updatedAt: base.subtract(const Duration(days: 1))),
    ];

    final List<LibraryItem> result = groupLibrary(entries, relations);

    final LibraryGroupItem group = result.single as LibraryGroupItem;
    expect(group.members.map((Entry e) => e.malId), <int>[2, 1]);
  });

  test('orders members by season year when the start date is missing', () {
    final Map<int, AnimeRelationNode> relations = <int, AnimeRelationNode>{
      1: AnimeRelationNode(
        malId: 1,
        title: 'T1',
        seasonYear: 2020,
        relations: <AnimeRelation>[_relation(2, RelationKind.sequel)],
      ),
      2: AnimeRelationNode(
        malId: 2,
        title: 'T2',
        seasonYear: 2010,
        relations: <AnimeRelation>[_relation(1, RelationKind.prequel)],
      ),
    };
    final List<Entry> entries = <Entry>[
      _entry(1, 'T1', updatedAt: base),
      _entry(2, 'T2', updatedAt: base.subtract(const Duration(days: 1))),
    ];

    final List<LibraryItem> result = groupLibrary(entries, relations);

    final LibraryGroupItem group = result.single as LibraryGroupItem;
    expect(group.members.map((Entry e) => e.malId), <int>[2, 1]);
  });

  test('puts members without any date last', () {
    final Map<int, AnimeRelationNode> relations = <int, AnimeRelationNode>{
      1: AnimeRelationNode(
        malId: 1,
        title: 'T1',
        startDate: const ReleaseDate(year: 2010),
        relations: <AnimeRelation>[_relation(2, RelationKind.sequel)],
      ),
      2: AnimeRelationNode(
        malId: 2,
        title: 'T2',
        relations: <AnimeRelation>[_relation(1, RelationKind.prequel)],
      ),
    };
    final List<Entry> entries = <Entry>[
      _entry(2, 'T2', updatedAt: base),
      _entry(1, 'T1', updatedAt: base.subtract(const Duration(days: 1))),
    ];

    final List<LibraryItem> result = groupLibrary(entries, relations);

    final LibraryGroupItem group = result.single as LibraryGroupItem;
    expect(group.members.map((Entry e) => e.malId), <int>[1, 2]);
  });

  test('breaks release date ties by title, ignoring diacritics', () {
    final Map<int, AnimeRelationNode> relations = <int, AnimeRelationNode>{
      1: AnimeRelationNode(
        malId: 1,
        title: 'Kuroko',
        startDate: const ReleaseDate(year: 2010),
        relations: <AnimeRelation>[_relation(2, RelationKind.sideStory)],
      ),
      2: AnimeRelationNode(
        malId: 2,
        title: 'Kōkaku',
        startDate: const ReleaseDate(year: 2010),
        relations: <AnimeRelation>[_relation(1, RelationKind.parentStory)],
      ),
    };
    final List<Entry> entries = <Entry>[
      _entry(1, 'Kuroko', updatedAt: base),
      _entry(2, 'Kōkaku', updatedAt: base.subtract(const Duration(days: 1))),
    ];

    final List<LibraryItem> result = groupLibrary(entries, relations);

    final LibraryGroupItem group = result.single as LibraryGroupItem;
    expect(group.members.map((Entry e) => e.malId), <int>[2, 1]);
  });

  test('labels the group with the title of the earliest release', () {
    final Map<int, AnimeRelationNode> relations = <int, AnimeRelationNode>{
      1: AnimeRelationNode(
        malId: 1,
        title: 'The earliest',
        startDate: const ReleaseDate(year: 2010),
        relations: <AnimeRelation>[_relation(2, RelationKind.sequel)],
      ),
      2: AnimeRelationNode(
        malId: 2,
        title: 'The latest',
        startDate: const ReleaseDate(year: 2020),
        relations: <AnimeRelation>[_relation(1, RelationKind.prequel)],
      ),
    };
    final List<Entry> entries = <Entry>[
      _entry(2, 'The latest', updatedAt: base),
      _entry(
        1,
        'The earliest',
        updatedAt: base.subtract(const Duration(days: 1)),
      ),
    ];

    final List<LibraryItem> result = groupLibrary(entries, relations);

    final LibraryGroupItem group = result.single as LibraryGroupItem;
    expect(group.label, 'The earliest');
  });

  test('places the group at its most recently updated member', () {
    final Map<int, AnimeRelationNode> relations = <int, AnimeRelationNode>{
      1: AnimeRelationNode(
        malId: 1,
        title: 'T1',
        startDate: const ReleaseDate(year: 2010),
        relations: <AnimeRelation>[_relation(2, RelationKind.sequel)],
      ),
      2: AnimeRelationNode(
        malId: 2,
        title: 'T2',
        startDate: const ReleaseDate(year: 2020),
        relations: <AnimeRelation>[_relation(1, RelationKind.prequel)],
      ),
    };
    // T1 is updated after the ungrouped entry, T2 before it.
    final List<Entry> entries = <Entry>[
      _entry(1, 'T1', updatedAt: base),
      _entry(
        9,
        'Standalone',
        updatedAt: base.subtract(const Duration(days: 1)),
      ),
      _entry(2, 'T2', updatedAt: base.subtract(const Duration(days: 2))),
    ];

    final List<LibraryItem> result = groupLibrary(entries, relations);

    expect(result, hasLength(2));
    expect(result[0], isA<LibraryGroupItem>());
    expect(result[1], isA<LibraryEntryItem>());
  });

  test(
    'uses the lowest MyAnimeList id as a group key that is stable across calls',
    () {
      final Map<int, AnimeRelationNode> relations = <int, AnimeRelationNode>{
        5: AnimeRelationNode(
          malId: 5,
          title: 'A',
          relations: <AnimeRelation>[_relation(3, RelationKind.prequel)],
        ),
        3: AnimeRelationNode(
          malId: 3,
          title: 'B',
          relations: <AnimeRelation>[_relation(5, RelationKind.sequel)],
        ),
      };
      final List<Entry> entries = <Entry>[
        _entry(5, 'A', updatedAt: base),
        _entry(3, 'B', updatedAt: base.subtract(const Duration(days: 1))),
      ];

      final LibraryGroupItem first =
          groupLibrary(entries, relations).single as LibraryGroupItem;
      final LibraryGroupItem second =
          groupLibrary(entries.reversed.toList(), relations).single
              as LibraryGroupItem;

      expect(first.key, 3);
      expect(second.key, 3);
    },
  );

  test('keeps the library flat and in order without relations', () {
    final List<Entry> entries = <Entry>[
      _entry(1, 'A', updatedAt: base),
      _entry(2, 'B', updatedAt: base.subtract(const Duration(days: 1))),
    ];

    final List<LibraryItem> result = groupLibrary(
      entries,
      const <int, AnimeRelationNode>{},
    );

    expect(result, <LibraryItem>[
      LibraryEntryItem(entries[0]),
      LibraryEntryItem(entries[1]),
    ]);
  });

  test('does not create items for neighbors missing from the library', () {
    final Map<int, AnimeRelationNode> relations = <int, AnimeRelationNode>{
      1: AnimeRelationNode(
        malId: 1,
        title: 'A',
        relations: <AnimeRelation>[_relation(99, RelationKind.sequel)],
      ),
    };
    final List<Entry> entries = <Entry>[
      _entry(1, 'A', updatedAt: base),
      _entry(2, 'B', updatedAt: base.subtract(const Duration(days: 1))),
    ];

    final List<LibraryItem> result = groupLibrary(entries, relations);

    expect(result, hasLength(2));
  });

  test(
    'keeps a long chain joined through a summary edge in a single group',
    () {
      final Map<int, AnimeRelationNode> relations = <int, AnimeRelationNode>{
        1: AnimeRelationNode(
          malId: 1,
          title: 'A',
          startDate: const ReleaseDate(year: 2001),
          relations: <AnimeRelation>[_relation(2, RelationKind.sequel)],
        ),
        2: AnimeRelationNode(
          malId: 2,
          title: 'B',
          startDate: const ReleaseDate(year: 2002),
          relations: <AnimeRelation>[
            _relation(1, RelationKind.prequel),
            _relation(3, RelationKind.summary),
          ],
        ),
        3: AnimeRelationNode(
          malId: 3,
          title: 'C',
          startDate: const ReleaseDate(year: 2003),
          relations: <AnimeRelation>[
            _relation(2, RelationKind.summary),
            _relation(4, RelationKind.sequel),
          ],
        ),
        4: AnimeRelationNode(
          malId: 4,
          title: 'D',
          startDate: const ReleaseDate(year: 2004),
          relations: <AnimeRelation>[_relation(3, RelationKind.prequel)],
        ),
      };
      final List<Entry> entries = <Entry>[
        _entry(1, 'A', updatedAt: base),
        _entry(2, 'B', updatedAt: base.subtract(const Duration(days: 1))),
        _entry(3, 'C', updatedAt: base.subtract(const Duration(days: 2))),
        _entry(4, 'D', updatedAt: base.subtract(const Duration(days: 3))),
      ];

      final List<LibraryItem> result = groupLibrary(entries, relations);

      expect(result, hasLength(1));
      final LibraryGroupItem group = result.single as LibraryGroupItem;
      expect(group.members.map((Entry e) => e.malId), <int>[1, 2, 3, 4]);
    },
  );
}
