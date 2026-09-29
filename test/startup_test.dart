import 'package:anihub/main.dart';
import 'package:anihub/ui/startup_error_app.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    final DebugPrintCallback originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {};
    addTearDown(() => debugPrint = originalDebugPrint);
  });

  test('shows the error screen when any startup step fails', () async {
    final Widget app = await startAniHub(
      () async => throw StateError('preferences unavailable'),
    );

    expect(app, isA<StartupErrorApp>());
  });

  test('runs the app that startup built', () async {
    const Widget built = SizedBox();

    expect(await startAniHub(() async => built), same(built));
  });
}
