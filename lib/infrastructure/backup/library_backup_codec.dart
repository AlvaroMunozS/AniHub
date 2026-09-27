import 'dart:convert';

import '../../domain/entities/entry.dart';
import '../../domain/errors/backup_format_exception.dart';
import '../../domain/values/watch_status.dart';

const String _format = 'anihub-library';
const int _version = 1;

/// Encodes [entries] as an `anihub-library` v1 document exported at
/// [exportedAt].
///
/// Entries are sorted by `malId`, so two exports of the same library differ
/// only in what changed. Every key is written, `null` included, and times are
/// in UTC with their microseconds, so [decodeLibraryBackup] returns the same
/// entries. The local `id` is left out: it means nothing on another device.
String encodeLibraryBackup(
  List<Entry> entries, {
  required DateTime exportedAt,
}) {
  final List<Entry> sorted = entries.toList()
    ..sort((Entry a, Entry b) => a.malId.compareTo(b.malId));
  return const JsonEncoder.withIndent('  ').convert(<String, Object?>{
    'format': _format,
    'version': _version,
    'exportedAt': exportedAt.toUtc().toIso8601String(),
    'entries': <Map<String, Object?>>[
      for (final Entry entry in sorted)
        <String, Object?>{
          'malId': entry.malId,
          'title': entry.title,
          'coverUrl': entry.coverUrl,
          'totalEpisodes': entry.totalEpisodes,
          'status': entry.status.wire,
          'isFavorite': entry.isFavorite,
          'updatedAt': entry.updatedAt.toUtc().toIso8601String(),
        },
    ],
  });
}

/// The file name suggested for a backup exported at [exportedAt], dated in
/// the device's time zone: `anihub-library-2026-09-27.json`.
String libraryBackupFileName(DateTime exportedAt) {
  final DateTime local = exportedAt.toLocal();
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '$_format-${local.year}-${twoDigits(local.month)}-'
      '${twoDigits(local.day)}.json';
}

/// Decodes an `anihub-library` v1 document into entries.
///
/// Throws [BackupFormatException] and rejects the whole file if the envelope
/// or any single entry is invalid. `malId`, a non-blank `title`, a known
/// `status` and an ISO 8601 `updatedAt` are required; optional fields with the
/// wrong type fall back to their defaults. Timestamps without an offset are
/// read as local time. When a `malId` appears more than once, only the entry
/// with the latest `updatedAt` is kept.
///
/// A favorite that is not completed keeps its status and loses the favorite
/// flag, since an [Entry] cannot hold both.
List<Entry> decodeLibraryBackup(String json) {
  final Object? decoded;
  try {
    decoded = jsonDecode(json);
  } on FormatException {
    throw const BackupFormatException('The file is not valid JSON.');
  }

  final List<Object?> rawEntries = switch (decoded) {
    {
      'format': _format,
      'version': _version,
      'entries': final List<Object?> entries,
    } =>
      entries,
    {'format': _format, 'version': _version} =>
      throw const BackupFormatException('The file has no "entries" list.'),
    {'format': _format} => throw const BackupFormatException(
      'The file is not version $_version.',
    ),
    _ => throw const BackupFormatException(
      'The file is not an "$_format" document.',
    ),
  };

  final Map<int, Entry> byMalId = <int, Entry>{};
  for (final Object? rawEntry in rawEntries) {
    final Entry entry = _decodeEntry(rawEntry);
    final Entry? existing = byMalId[entry.malId];
    if (existing == null || entry.updatedAt.isAfter(existing.updatedAt)) {
      byMalId[entry.malId] = entry;
    }
  }
  return byMalId.values.toList(growable: false);
}

Entry _decodeEntry(Object? rawEntry) {
  if (rawEntry
      case {
        'malId': final int malId,
        'title': final String title,
        'status': final String rawStatus,
        'updatedAt': final String rawUpdatedAt,
      }
      when title.trim().isNotEmpty) {
    final WatchStatus? status = WatchStatus.tryFromWire(rawStatus);
    if (status == null) {
      throw BackupFormatException('Entry $malId has an unknown status.');
    }
    final DateTime? updatedAt = DateTime.tryParse(rawUpdatedAt)?.toUtc();
    if (updatedAt == null) {
      throw BackupFormatException('Entry $malId has an invalid updatedAt.');
    }
    return Entry(
      malId: malId,
      title: title,
      coverUrl: switch (rawEntry['coverUrl']) {
        final String url => url,
        _ => null,
      },
      totalEpisodes: switch (rawEntry['totalEpisodes']) {
        final int count when count >= 0 => count,
        _ => null,
      },
      status: status,
      isFavorite:
          rawEntry['isFavorite'] == true && status == WatchStatus.completed,
      updatedAt: updatedAt,
    );
  }
  throw const BackupFormatException(
    'An entry lacks malId, title, status or updatedAt.',
  );
}
