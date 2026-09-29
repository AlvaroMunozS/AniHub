import 'dart:convert';

import 'package:anihub/application/usecases/usecases.dart';
import 'package:anihub/domain/entities/entry.dart';
import 'package:anihub/domain/errors/backup_format_exception.dart';
import 'package:anihub/domain/values/watch_status.dart';
import 'package:anihub/infrastructure/backup/library_backup_codec.dart';
import 'package:anihub/infrastructure/local/sqflite_entry_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

String _validJson({List<Map<String, Object?>>? entries}) {
  return jsonEncode(<String, Object?>{
    'format': 'anihub-library',
    'version': 1,
    'exportedAt': '2026-09-22T10:00:00Z',
    'entries':
        entries ??
        <Map<String, Object?>>[
          <String, Object?>{
            'malId': 1,
            'title': 'Frieren',
            'coverUrl': 'https://example.com/frieren.jpg',
            'totalEpisodes': 28,
            'status': 'completed',
            'isFavorite': true,
            'updatedAt': '2026-09-20T10:00:00.123456+00:00',
          },
        ],
  });
}

final DateTime _exportedAt = DateTime.utc(2026, 9, 27, 18, 4, 12, 345, 678);

/// One entry of each kind: every field set, optional fields null, and a
/// timestamp with microseconds.
final List<Entry> _library = <Entry>[
  Entry(
    id: 'local-2',
    malId: 52991,
    title: 'Frieren',
    coverUrl: 'https://example.com/frieren.jpg',
    totalEpisodes: 28,
    status: WatchStatus.completed,
    isFavorite: true,
    updatedAt: DateTime.utc(2026, 9, 20, 10, 0, 0, 123, 456),
  ),
  Entry(
    id: 'local-1',
    malId: 21,
    title: 'One Piece',
    status: WatchStatus.watching,
    updatedAt: DateTime.utc(2026, 9, 21),
  ),
];

/// [entry] as a backup holds it, without the id local to this device.
Entry _withoutId(Entry entry) => Entry(
  malId: entry.malId,
  title: entry.title,
  coverUrl: entry.coverUrl,
  totalEpisodes: entry.totalEpisodes,
  status: entry.status,
  isFavorite: entry.isFavorite,
  updatedAt: entry.updatedAt,
);

Future<Database> _openLibraryDatabase() async {
  final Database db = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 2,
      singleInstance: false,
      onCreate: (Database db, int _) => createAniHubSchema(db),
    ),
  );
  addTearDown(db.close);
  return db;
}

void main() {
  sqfliteFfiInit();

  group('encodeLibraryBackup', () {
    test('writes the envelope and every field, sorted by malId', () {
      final Object? document = jsonDecode(
        encodeLibraryBackup(_library, exportedAt: _exportedAt),
      );

      expect(document, <String, Object?>{
        'format': 'anihub-library',
        'version': 1,
        'exportedAt': '2026-09-27T18:04:12.345678Z',
        'entries': <Map<String, Object?>>[
          <String, Object?>{
            'malId': 21,
            'title': 'One Piece',
            'coverUrl': null,
            'totalEpisodes': null,
            'status': 'watching',
            'isFavorite': false,
            'updatedAt': '2026-09-21T00:00:00.000Z',
          },
          <String, Object?>{
            'malId': 52991,
            'title': 'Frieren',
            'coverUrl': 'https://example.com/frieren.jpg',
            'totalEpisodes': 28,
            'status': 'completed',
            'isFavorite': true,
            'updatedAt': '2026-09-20T10:00:00.123456Z',
          },
        ],
      });
    });

    test('writes local times in UTC', () {
      final String json = encodeLibraryBackup(<Entry>[
        Entry(
          malId: 1,
          title: 'Cowboy Bebop',
          status: WatchStatus.planned,
          updatedAt: DateTime(2026, 9, 20, 10),
        ),
      ], exportedAt: DateTime(2026, 9, 27, 18));

      final Map<String, Object?> document =
          jsonDecode(json) as Map<String, Object?>;
      final Map<String, Object?> entry =
          (document['entries']! as List<Object?>).single!
              as Map<String, Object?>;
      for (final (Object? written, DateTime time) in <(Object?, DateTime)>[
        (document['exportedAt'], DateTime(2026, 9, 27, 18)),
        (entry['updatedAt'], DateTime(2026, 9, 20, 10)),
      ]) {
        expect(written, endsWith('Z'));
        expect(
          DateTime.parse(written! as String).isAtSameMomentAs(time),
          isTrue,
        );
      }
    });

    test('indents the JSON with two spaces', () {
      final String json = encodeLibraryBackup(
        const <Entry>[],
        exportedAt: _exportedAt,
      );

      expect(json, startsWith('{\n  "format": "anihub-library",\n'));
    });

    test('decodes back to the same entries, without the local id', () {
      final List<Entry> decoded = decodeLibraryBackup(
        encodeLibraryBackup(_library, exportedAt: _exportedAt),
      );

      expect(decoded, unorderedEquals(_library.map(_withoutId)));
    });

    test('an export of the stored library reads back exactly and imports as '
        'unchanged', () async {
      final SqfliteEntryRepository repository = SqfliteEntryRepository(
        await _openLibraryDatabase(),
      );
      addTearDown(repository.dispose);
      await repository.upsertAll(_library.map(_withoutId).toList());
      final List<Entry> stored = await repository.findAll();

      final List<Entry> decoded = decodeLibraryBackup(
        encodeLibraryBackup(stored, exportedAt: _exportedAt),
      );
      final ImportSummary summary = await ImportLibrary(
        repository,
        DateTime.now,
      )(decoded);

      expect(decoded, unorderedEquals(stored.map(_withoutId)));
      expect(summary.added, 0);
      expect(summary.updated, 0);
      expect(summary.unchanged, _library.length);
    });
  });

  group('libraryBackupFileName', () {
    test('names the file after the local date, zero-padded', () {
      for (final DateTime exportedAt in <DateTime>[
        DateTime(2026, 3, 7),
        DateTime(2026, 3, 7, 23, 59),
      ]) {
        expect(
          libraryBackupFileName(exportedAt),
          'anihub-library-2026-03-07.json',
          reason: '$exportedAt',
        );
      }
    });
  });

  group('decodeLibraryBackup', () {
    test('decodes a valid file with every field', () {
      final List<Entry> entries = decodeLibraryBackup(_validJson());

      expect(entries, hasLength(1));
      final Entry entry = entries.single;
      expect(entry.malId, 1);
      expect(entry.title, 'Frieren');
      expect(entry.coverUrl, 'https://example.com/frieren.jpg');
      expect(entry.totalEpisodes, 28);
      expect(entry.status, WatchStatus.completed);
      expect(entry.isFavorite, isTrue);
      expect(
        entry.updatedAt,
        DateTime.parse('2026-09-20T10:00:00.123456+00:00'),
      );
      expect(entry.id, isNull);
    });

    test('accepts null optional fields', () {
      final String json = jsonEncode(<String, Object?>{
        'format': 'anihub-library',
        'version': 1,
        'exportedAt': '2026-09-22T10:00:00+00:00',
        'entries': <Map<String, Object?>>[
          <String, Object?>{
            'malId': 42,
            'title': 'One Piece',
            'coverUrl': null,
            'totalEpisodes': null,
            'status': 'planned',
            'isFavorite': false,
            'updatedAt': '2026-09-20T10:00:00.123456+00:00',
          },
        ],
      });

      final List<Entry> entries = decodeLibraryBackup(json);
      expect(entries, hasLength(1));
      expect(entries.single.coverUrl, isNull);
      expect(entries.single.totalEpisodes, isNull);
      expect(
        entries.single.updatedAt,
        DateTime.parse('2026-09-20T10:00:00.123456+00:00'),
      );
    });

    test('decodes an empty entries list', () {
      final String json = jsonEncode(<String, Object?>{
        'format': 'anihub-library',
        'version': 1,
        'exportedAt': '2026-09-22T10:00:00Z',
        'entries': <Object?>[],
      });

      expect(decodeLibraryBackup(json), isEmpty);
    });

    test('rejects malformed JSON', () {
      expect(
        () => decodeLibraryBackup('this is not json'),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('rejects an unknown format', () {
      final String json = jsonEncode(<String, Object?>{
        'format': 'something-else',
        'version': 1,
        'entries': <Object?>[],
      });

      expect(
        () => decodeLibraryBackup(json),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('rejects an unsupported version', () {
      final String json = jsonEncode(<String, Object?>{
        'format': 'anihub-library',
        'version': 2,
        'entries': <Object?>[],
      });

      expect(
        () => decodeLibraryBackup(json),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('rejects the whole file when an entry has an invalid status', () {
      final String json = _validJson(
        entries: <Map<String, Object?>>[
          <String, Object?>{
            'malId': 1,
            'title': 'Frieren',
            'status': 'dropped',
            'updatedAt': '2026-09-20T10:00:00Z',
          },
        ],
      );

      expect(
        () => decodeLibraryBackup(json),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('rejects the whole file when an entry lacks malId', () {
      final String json = _validJson(
        entries: <Map<String, Object?>>[
          <String, Object?>{
            'title': 'Frieren',
            'status': 'watching',
            'updatedAt': '2026-09-20T10:00:00Z',
          },
        ],
      );

      expect(
        () => decodeLibraryBackup(json),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('rejects the whole file when an entry lacks a title', () {
      final String json = _validJson(
        entries: <Map<String, Object?>>[
          <String, Object?>{
            'malId': 1,
            'status': 'watching',
            'updatedAt': '2026-09-20T10:00:00Z',
          },
        ],
      );

      expect(
        () => decodeLibraryBackup(json),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('rejects the whole file when updatedAt is not ISO 8601', () {
      final String json = _validJson(
        entries: <Map<String, Object?>>[
          <String, Object?>{
            'malId': 1,
            'title': 'Frieren',
            'status': 'watching',
            'updatedAt': 'not-a-date',
          },
        ],
      );

      expect(
        () => decodeLibraryBackup(json),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('rejects the whole file when a title is blank', () {
      expect(
        () => decodeLibraryBackup(
          _validJson(
            entries: <Map<String, Object?>>[
              <String, Object?>{
                'malId': 1,
                'title': '   ',
                'status': 'planned',
                'updatedAt': '2026-09-20T10:00:00Z',
              },
            ],
          ),
        ),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('rejects a file without an entries list or that is not an object', () {
      for (final Object? document in <Object?>[
        <String, Object?>{'format': 'anihub-library', 'version': 1},
        <String, Object?>{
          'format': 'anihub-library',
          'version': 1,
          'entries': <String, Object?>{},
        },
        <Object?>[],
      ]) {
        expect(
          () => decodeLibraryBackup(jsonEncode(document)),
          throwsA(isA<BackupFormatException>()),
          reason: '$document',
        );
      }
    });

    test('drops optional fields of the wrong type or a negative count', () {
      final List<Entry> entries = decodeLibraryBackup(
        _validJson(
          entries: <Map<String, Object?>>[
            <String, Object?>{
              'malId': 1,
              'title': 'Frieren',
              'coverUrl': 42,
              'totalEpisodes': -3,
              'isFavorite': 'yes',
              'status': 'planned',
              'updatedAt': '2026-09-20T10:00:00Z',
            },
          ],
        ),
      );

      expect(entries.single.coverUrl, isNull);
      expect(entries.single.totalEpisodes, isNull);
      expect(entries.single.isFavorite, isFalse);
    });

    test('drops the favorite of an entry that is not completed, keeping its '
        'status', () {
      final List<Entry> entries = decodeLibraryBackup(
        _validJson(
          entries: <Map<String, Object?>>[
            <String, Object?>{
              'malId': 1,
              'title': 'Frieren',
              'status': 'watching',
              'isFavorite': true,
              'updatedAt': '2026-09-20T10:00:00Z',
            },
          ],
        ),
      );

      expect(entries.single.status, WatchStatus.watching);
      expect(entries.single.isFavorite, isFalse);
    });

    test('reads a timestamp without offset as local time, stored in UTC', () {
      final List<Entry> entries = decodeLibraryBackup(
        _validJson(
          entries: <Map<String, Object?>>[
            <String, Object?>{
              'malId': 1,
              'title': 'Frieren',
              'status': 'planned',
              'updatedAt': '2026-09-20T10:00:00',
            },
          ],
        ),
      );

      expect(entries.single.updatedAt.isUtc, isTrue);
      expect(
        entries.single.updatedAt.isAtSameMomentAs(DateTime(2026, 9, 20, 10)),
        isTrue,
      );
    });

    test('keeps the newest entry for a duplicated malId', () {
      final String json = _validJson(
        entries: <Map<String, Object?>>[
          <String, Object?>{
            'malId': 1,
            'title': 'Old version',
            'status': 'planned',
            'updatedAt': '2020-01-01T00:00:00Z',
          },
          <String, Object?>{
            'malId': 1,
            'title': 'New version',
            'status': 'completed',
            'updatedAt': '2025-01-01T00:00:00Z',
          },
        ],
      );

      final List<Entry> entries = decodeLibraryBackup(json);
      expect(entries, hasLength(1));
      expect(entries.single.title, 'New version');
      expect(entries.single.status, WatchStatus.completed);
    });
  });
}
