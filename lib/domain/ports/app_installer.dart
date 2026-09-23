import '../entities/app_release.dart';
import '../errors/update_exception.dart';

/// Installs a release over the running app.
abstract interface class AppInstaller {
  /// Downloads the APK of [release], checks its SHA-256 and hands it to the
  /// system installer.
  ///
  /// [onProgress] receives the downloaded fraction, from 0 to 1. Returns false
  /// if the user cancels the installation; on success the process is replaced
  /// and the future never completes. Throws an [UpdateException] if any step
  /// fails.
  Future<bool> install(
    AppRelease release, {
    void Function(double progress)? onProgress,
  });
}
