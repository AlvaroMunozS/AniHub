import 'dart:io';

import '../../domain/entities/app_release.dart';
import '../../domain/ports/app_installer.dart';
import 'apk_downloader.dart';
import 'platform_package_installer.dart';

/// Downloads a release with [ApkDownloader] and installs it with
/// [PlatformPackageInstaller].
class AndroidAppInstaller implements AppInstaller {
  const AndroidAppInstaller(this._downloader, this._installer);

  final ApkDownloader _downloader;
  final PlatformPackageInstaller _installer;

  @override
  Future<bool> install(
    AppRelease release, {
    void Function(double progress)? onProgress,
  }) async {
    final File apk = await _downloader.download(
      release,
      onProgress: onProgress,
    );
    try {
      return await _installer.install(apk);
    } finally {
      // The native side deletes the file once it is copied into the install
      // session; this covers failures before that point.
      if (await apk.exists()) await apk.delete();
    }
  }
}
