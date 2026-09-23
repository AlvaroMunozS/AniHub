import 'dart:async';

import 'package:anihub/domain/entities/app_release.dart';
import 'package:anihub/domain/ports/app_installer.dart';

/// An installer the test drives: it reports progress through [progress] and
/// finishes when [completer] completes.
class FakeAppInstaller implements AppInstaller {
  final List<AppRelease> installed = <AppRelease>[];
  Completer<bool> completer = Completer<bool>();
  void Function(double progress)? _onProgress;

  @override
  Future<bool> install(
    AppRelease release, {
    void Function(double progress)? onProgress,
  }) {
    installed.add(release);
    _onProgress = onProgress;
    return completer.future;
  }

  void progress(double value) => _onProgress?.call(value);
}
