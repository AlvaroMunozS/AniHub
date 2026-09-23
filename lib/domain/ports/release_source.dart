import '../entities/app_release.dart';
import '../errors/update_exception.dart';

/// Published releases of the app.
abstract interface class ReleaseSource {
  /// Returns the newest published release, or null when there is none.
  ///
  /// Pre-releases are considered only when [includePrereleases] is true.
  /// Throws an [UpdateException] if the request fails or the release has no
  /// verifiable APK.
  Future<AppRelease?> latest({required bool includePrereleases});
}
