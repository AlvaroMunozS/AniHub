import '../values/app_version.dart';

/// A published release of the app with its installable APK.
class AppRelease {
  const AppRelease({
    required this.version,
    required this.pageUrl,
    required this.apkUrl,
    required this.apkSha256,
    required this.apkSize,
  });

  final AppVersion version;

  /// The release page, with its notes.
  final Uri pageUrl;

  final Uri apkUrl;

  /// SHA-256 digest of the APK, in lowercase hex.
  final String apkSha256;

  /// Size of the APK in bytes.
  final int apkSize;

  @override
  String toString() => 'AppRelease($version)';
}
