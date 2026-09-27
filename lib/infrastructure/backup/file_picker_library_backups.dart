import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../../domain/entities/entry.dart';
import '../../domain/errors/backup_format_exception.dart';
import '../../domain/ports/library_backups.dart';
import 'library_backup_codec.dart';

class FilePickerLibraryBackups implements LibraryBackups {
  const FilePickerLibraryBackups();

  @override
  Future<List<Entry>?> pickLibrary() async {
    final PlatformFile? file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: <String>['json'],
    );

    if (file == null) return null;

    final Uint8List bytes = await file.readAsBytes();
    final String json;
    try {
      json = utf8.decode(bytes);
    } on FormatException {
      throw const BackupFormatException('The file is not UTF-8.');
    }
    return decodeLibraryBackup(json);
  }

  @override
  Future<bool> saveLibrary(
    List<Entry> entries, {
    required DateTime exportedAt,
  }) async {
    final Uri? saved = await FilePicker.saveFile(
      fileName: libraryBackupFileName(exportedAt),
      bytes: utf8.encode(encodeLibraryBackup(entries, exportedAt: exportedAt)),
      mimeType: 'application/json',
    );
    return saved != null;
  }
}
