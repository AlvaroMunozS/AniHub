import 'dart:async';
import 'dart:convert';

import 'package:anihub/domain/entities/app_release.dart';
import 'package:anihub/domain/errors/update_exception.dart';
import 'package:anihub/infrastructure/github/github_release_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final String _digest = 'ab' * 32;

Map<String, Object?> _release(
  String tag, {
  bool draft = false,
  bool prerelease = false,
  List<Map<String, Object?>>? assets,
}) => <String, Object?>{
  'tag_name': tag,
  'draft': draft,
  'prerelease': prerelease,
  'html_url': 'https://github.com/AlvaroMunozS/AniHub/releases/tag/$tag',
  'assets':
      assets ??
      <Map<String, Object?>>[
        _asset('anihub-$tag.apk'),
        _asset('anihub-$tag.apk.sha256', digest: 'sha256:${'cd' * 32}'),
      ],
};

Map<String, Object?> _asset(String name, {Object? digest}) => <String, Object?>{
  'name': name,
  'size': 1234,
  'browser_download_url':
      'https://github.com/AlvaroMunozS/AniHub/releases/download/x/$name',
  'digest': digest ?? 'sha256:$_digest',
};

http.Response _json(Object? body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status);

/// Answers every request with [respond] and records it in [requests].
class _Api {
  _Api(this.respond);

  final Future<http.Response> Function(Uri url) respond;
  final List<http.BaseRequest> requests = <http.BaseRequest>[];

  GitHubReleaseSource source({Duration timeout = const Duration(seconds: 1)}) =>
      GitHubReleaseSource(
        MockClient((http.Request request) {
          requests.add(request);
          return respond(request.url);
        }),
        timeout: timeout,
      );
}

void main() {
  test('reads the latest stable release with its APK', () async {
    final _Api api = _Api((_) async => _json(_release('v1.1.0')));

    final AppRelease? release = await api.source().latest(
      includePrereleases: false,
    );

    expect(
      api.requests.single.url.toString(),
      'https://api.github.com/repos/AlvaroMunozS/AniHub/releases/latest',
    );
    expect(release!.version.toString(), '1.1.0');
    expect(release.apkSha256, _digest);
    expect(release.apkSize, 1234);
    expect(release.apkUrl.path, endsWith('/anihub-v1.1.0.apk'));
    expect(release.pageUrl.path, endsWith('/tag/v1.1.0'));
  });

  test('sends the headers GitHub requires', () async {
    final _Api api = _Api((_) async => _json(_release('v1.1.0')));

    await api.source().latest(includePrereleases: false);

    final Map<String, String> headers = api.requests.single.headers;
    expect(headers['User-Agent'], 'AniHub');
    expect(headers['Accept'], 'application/vnd.github+json');
    expect(headers['X-GitHub-Api-Version'], isNotEmpty);
  });

  test('returns null when there is no release', () async {
    final _Api api = _Api((_) async => _json(<String, Object?>{}, 404));

    expect(await api.source().latest(includePrereleases: false), isNull);
  });

  test('picks the highest version, pre-releases included, skipping drafts '
      'and foreign tags', () async {
    final _Api api = _Api(
      (_) async => _json(<Object?>[
        _release('v2.0.0', draft: true),
        _release('nightly'),
        _release('v1.0.0'),
        _release('v1.1.0-beta.2', prerelease: true),
        _release('v1.1.0-beta.10', prerelease: true),
      ]),
    );

    final AppRelease? release = await api.source().latest(
      includePrereleases: true,
    );

    expect(api.requests.single.url.path, '/repos/AlvaroMunozS/AniHub/releases');
    expect(api.requests.single.url.queryParameters['per_page'], '30');
    expect(release!.version.toString(), '1.1.0-beta.10');
  });

  test('returns null when every listed release is a draft', () async {
    final _Api api = _Api(
      (_) async => _json(<Object?>[_release('v2.0.0', draft: true)]),
    );

    expect(await api.source().latest(includePrereleases: true), isNull);
  });

  for (final (String name, List<Map<String, Object?>> assets)
      in <(String, List<Map<String, Object?>>)>[
        ('no APK', <Map<String, Object?>>[_asset('notes.txt')]),
        ('two APKs', <Map<String, Object?>>[_asset('a.apk'), _asset('b.apk')]),
        (
          'an APK without a digest',
          <Map<String, Object?>>[
            <String, Object?>{..._asset('a.apk'), 'digest': null},
          ],
        ),
        (
          'an APK with another digest',
          <Map<String, Object?>>[_asset('a.apk', digest: 'sha512:abc')],
        ),
      ]) {
    test('rejects a release with $name', () async {
      final _Api api = _Api(
        (_) async => _json(_release('v1.1.0', assets: assets)),
      );

      await expectLater(
        api.source().latest(includePrereleases: false),
        throwsA(isA<UpdateResponseException>()),
      );
    });
  }

  test('reports an exhausted rate limit', () async {
    for (final http.Response response in <http.Response>[
      http.Response(
        '',
        403,
        headers: <String, String>{'x-ratelimit-remaining': '0'},
      ),
      http.Response('', 429),
    ]) {
      final _Api api = _Api((_) async => response);

      await expectLater(
        api.source().latest(includePrereleases: false),
        throwsA(isA<UpdateRateLimitException>()),
      );
    }
  });

  test('reports other errors as unexpected responses', () async {
    for (final http.Response response in <http.Response>[
      http.Response('', 403),
      http.Response('', 500),
      http.Response('not json', 200),
      _json(<Object?>[]),
    ]) {
      final _Api api = _Api((_) async => response);

      await expectLater(
        api.source().latest(includePrereleases: false),
        throwsA(isA<UpdateResponseException>()),
      );
    }
  });

  test('reports a network failure', () async {
    final _Api api = _Api((Uri url) async {
      throw http.ClientException('offline', url);
    });

    await expectLater(
      api.source().latest(includePrereleases: false),
      throwsA(isA<UpdateNetworkException>()),
    );
  });

  test('reports a timeout', () async {
    final _Api api = _Api((_) => Completer<http.Response>().future);

    await expectLater(
      api.source(timeout: Duration.zero).latest(includePrereleases: false),
      throwsA(isA<UpdateTimeoutException>()),
    );
  });
}
