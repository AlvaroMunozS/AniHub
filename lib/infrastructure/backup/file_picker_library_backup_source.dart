import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../../domain/entities/entry.dart';
import '../../domain/errors/backup_format_exception.dart';
import '../../domain/ports/library_backup_source.dart';
import 'library_backup_codec.dart';

class FilePickerLibraryBackupSource implements LibraryBackupSource {
  const FilePickerLibraryBackupSource();

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
}
