import 'package:anihub/domain/entities/app_release.dart';
import 'package:anihub/domain/ports/release_source.dart';
import 'package:anihub/domain/values/app_version.dart';

/// Returns [release], or throws [error] when it is set, and records the
/// `includePrereleases` flag of every request.
class FakeReleaseSource implements ReleaseSource {
  FakeReleaseSource({this.release, this.error});

  AppRelease? release;
  Object? error;
  final List<bool> requests = <bool>[];

  @override
  Future<AppRelease?> latest({required bool includePrereleases}) async {
    requests.add(includePrereleases);
    if (error case final Object error) throw error;
    return release;
  }
}

/// A release of [version] with a placeholder APK.
AppRelease sampleRelease(String version) => AppRelease(
  version: AppVersion.tryParse(version)!,
  pageUrl: Uri.parse('https://github.com/o/r/releases/tag/v$version'),
  apkUrl: Uri.parse('https://github.com/o/r/releases/download/v$version/a.apk'),
  apkSha256: '0' * 64,
  apkSize: 100,
);
