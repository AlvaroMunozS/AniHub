import 'dart:io';

import 'package:anihub/domain/entities/app_release.dart';
import 'package:anihub/domain/errors/update_exception.dart';
import 'package:anihub/domain/values/app_version.dart';
import 'package:anihub/infrastructure/update/android_app_installer.dart';
import 'package:anihub/infrastructure/update/apk_downloader.dart';
import 'package:anihub/infrastructure/update/platform_package_installer.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const MethodChannel _channel = MethodChannel('anihub/installer');
final List<int> _bytes = List<int>.filled(64, 7);

final AppRelease _release = AppRelease(
  version: AppVersion.tryParse('1.1.0')!,
  pageUrl: Uri.parse('https://github.com/o/r/releases/tag/v1.1.0'),
  apkUrl: Uri.parse('https://github.com/o/r/releases/download/v1.1.0/a.apk'),
  apkSha256: sha256.convert(_bytes).toString(),
  apkSize: _bytes.length,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late AndroidAppInstaller installer;
  final List<bool> fileExistedWhenInstalling = <bool>[];

  void answer(Object? Function() respond) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (MethodCall call) async {
          final String path =
              (call.arguments as Map<Object?, Object?>)['path']! as String;
          fileExistedWhenInstalling.add(File(path).existsSync());
          return respond();
        });
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('anihub_install_test');
    installer = AndroidAppInstaller(
      ApkDownloader(
        MockClient((_) async => http.Response.bytes(_bytes, 200)),
        directory: directory,
        timeout: const Duration(seconds: 1),
      ),
      const PlatformPackageInstaller(),
    );
  });

  tearDown(() async {
    fileExistedWhenInstalling.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    await directory.delete(recursive: true);
  });

  bool apkLeft() => directory.listSync().isNotEmpty;

  test('hands the verified APK to the installer and removes it', () async {
    answer(() => 'cancelled');

    expect(await installer.install(_release), isFalse);
    expect(fileExistedWhenInstalling, <bool>[true]);
    expect(apkLeft(), isFalse);
  });

  test('removes the APK when the installer fails', () async {
    answer(() => throw PlatformException(code: 'install_failed'));

    await expectLater(
      installer.install(_release),
      throwsA(isA<UpdateInstallException>()),
    );
    expect(apkLeft(), isFalse);
  });
}
