import 'dart:convert';

import 'package:anihub/domain/entities/entry.dart';
import 'package:anihub/domain/errors/backup_format_exception.dart';
import 'package:anihub/domain/values/watch_status.dart';
import 'package:anihub/infrastructure/backup/library_backup_codec.dart';
import 'package:flutter_test/flutter_test.dart';

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

void main() {
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
