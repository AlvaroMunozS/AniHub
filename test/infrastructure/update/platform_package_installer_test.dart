import 'dart:io';

import 'package:anihub/domain/errors/update_exception.dart';
import 'package:anihub/infrastructure/update/platform_package_installer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const MethodChannel _channel = MethodChannel('anihub/installer');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<MethodCall> calls = <MethodCall>[];

  void answer(Object? Function() respond) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (MethodCall call) async {
          calls.add(call);
          return respond();
        });
  }

  tearDown(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  test('sends the APK path to the native installer', () async {
    answer(() => 'success');

    expect(
      await const PlatformPackageInstaller().install(File('/c/u.apk')),
      isTrue,
    );
    expect(calls.single.method, 'install');
    expect(calls.single.arguments, <String, Object?>{'path': '/c/u.apk'});
  });

  test('returns false when the user cancels', () async {
    answer(() => 'cancelled');

    expect(
      await const PlatformPackageInstaller().install(File('/c/u.apk')),
      isFalse,
    );
  });

  test('reports an installer failure', () async {
    answer(
      () => throw PlatformException(
        code: 'install_failed',
        message: 'INSTALL_FAILED_UPDATE_INCOMPATIBLE',
      ),
    );

    await expectLater(
      const PlatformPackageInstaller().install(File('/c/u.apk')),
      throwsA(
        isA<UpdateInstallException>().having(
          (UpdateInstallException e) => e.message,
          'message',
          'INSTALL_FAILED_UPDATE_INCOMPATIBLE',
        ),
      ),
    );
  });
}
