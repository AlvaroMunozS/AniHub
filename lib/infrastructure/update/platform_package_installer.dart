import 'dart:io';

import 'package:flutter/services.dart';

import '../../domain/errors/update_exception.dart';

/// Hands an APK to Android's `PackageInstaller` through the `ApkInstaller`
/// channel in `MainActivity`.
class PlatformPackageInstaller {
  const PlatformPackageInstaller([
    this._channel = const MethodChannel('anihub/installer'),
  ]);

  final MethodChannel _channel;

  /// Installs [apk] over the running app.
  ///
  /// Returns false if the user cancels the installation. On success Android
  /// replaces the process, so the future usually never completes. Throws
  /// [UpdateInstallException] if the installer rejects the APK.
  Future<bool> install(File apk) async {
    try {
      final String? result = await _channel.invokeMethod<String>(
        'install',
        <String, Object?>{'path': apk.path},
      );
      return switch (result) {
        'success' => true,
        'cancelled' => false,
        _ => throw UpdateInstallException(
          'Unexpected installer answer: $result',
        ),
      };
    } on PlatformException catch (error) {
      throw UpdateInstallException(error.message ?? error.code);
    }
  }
}
