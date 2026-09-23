import '../../domain/entities/app_release.dart';
import '../../domain/errors/update_exception.dart';
import '../../domain/ports/release_source.dart';
import '../../domain/values/app_version.dart';

/// Finds a release newer than the installed version.
class CheckForUpdate {
  const CheckForUpdate(this._source);

  final ReleaseSource _source;

  /// Returns the newest release if it is newer than [installedVersion], or
  /// null if the app is up to date.
  ///
  /// With [includePrereleases] off, an installed pre-release stays put until
  /// a newer stable version exists. Throws an [UpdateException] if the check
  /// fails or [installedVersion] is not a semantic version.
  Future<AppRelease?> call({
    required String installedVersion,
    required bool includePrereleases,
  }) async {
    final AppVersion? installed = AppVersion.tryParse(installedVersion);
    if (installed == null) {
      throw UpdateResponseException(
        'Installed version "$installedVersion" is not a semantic version',
      );
    }
    final AppRelease? latest = await _source.latest(
      includePrereleases: includePrereleases,
    );
    return latest != null && latest.version > installed ? latest : null;
  }
}
