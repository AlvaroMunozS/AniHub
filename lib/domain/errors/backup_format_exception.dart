/// Thrown when a file picked for import is not a valid `anihub-library`
/// backup.
class BackupFormatException implements Exception {
  const BackupFormatException(this.message);

  final String message;

  @override
  String toString() => 'BackupFormatException: $message';
}
