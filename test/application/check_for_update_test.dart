import 'package:anihub/application/updates/check_for_update.dart';
import 'package:anihub/domain/entities/app_release.dart';
import 'package:anihub/domain/errors/update_exception.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_release_source.dart';

void main() {
  test('returns a newer release', () async {
    final CheckForUpdate check = CheckForUpdate(
      FakeReleaseSource(release: sampleRelease('1.1.0')),
    );

    final AppRelease? result = await check(
      installedVersion: '1.0.0',
      includePrereleases: false,
    );

    expect(result?.version.toString(), '1.1.0');
  });

  test('returns null when the latest release is installed or older', () async {
    for (final String latest in <String>['1.0.0', '0.9.0']) {
      final CheckForUpdate check = CheckForUpdate(
        FakeReleaseSource(release: sampleRelease(latest)),
      );

      expect(
        await check(installedVersion: '1.0.0', includePrereleases: false),
        isNull,
        reason: latest,
      );
    }
  });

  test('returns null when there is no release', () async {
    final CheckForUpdate check = CheckForUpdate(FakeReleaseSource());

    expect(
      await check(installedVersion: '1.0.0', includePrereleases: false),
      isNull,
    );
  });

  test(
    'keeps an installed pre-release over the previous stable version',
    () async {
      final CheckForUpdate check = CheckForUpdate(
        FakeReleaseSource(release: sampleRelease('1.0.0')),
      );

      expect(
        await check(
          installedVersion: '1.1.0-beta.1',
          includePrereleases: false,
        ),
        isNull,
      );
    },
  );

  test('offers the stable version of an installed pre-release', () async {
    final CheckForUpdate check = CheckForUpdate(
      FakeReleaseSource(release: sampleRelease('1.1.0')),
    );

    final AppRelease? result = await check(
      installedVersion: '1.1.0-beta.1',
      includePrereleases: false,
    );

    expect(result?.version.toString(), '1.1.0');
  });

  test('passes the pre-release preference to the source', () async {
    final FakeReleaseSource source = FakeReleaseSource();

    await CheckForUpdate(source)(
      installedVersion: '1.0.0',
      includePrereleases: true,
    );

    expect(source.requests, <bool>[true]);
  });

  test('rejects an installed version that is not semantic', () async {
    final FakeReleaseSource source = FakeReleaseSource();

    await expectLater(
      CheckForUpdate(source)(
        installedVersion: '1.0',
        includePrereleases: false,
      ),
      throwsA(isA<UpdateResponseException>()),
    );
    expect(source.requests, isEmpty);
  });
}
