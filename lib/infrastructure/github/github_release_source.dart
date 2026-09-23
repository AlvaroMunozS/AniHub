import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../domain/entities/app_release.dart';
import '../../domain/errors/update_exception.dart';
import '../../domain/ports/release_source.dart';
import '../../domain/values/app_version.dart';

/// Reads the releases of the AniHub repository from the GitHub REST API.
///
/// Requests are unauthenticated, which GitHub limits to 60 per hour and IP.
class GitHubReleaseSource implements ReleaseSource {
  GitHubReleaseSource(this._client, {required this.timeout});

  static const String _host = 'api.github.com';
  static const String _releasesPath = '/repos/AlvaroMunozS/AniHub/releases';

  /// Enough to reach the newest release even after a run of pre-releases.
  static const int _pageSize = 30;

  static final RegExp _sha256Digest = RegExp(r'^sha256:([0-9a-f]{64})$');

  final http.Client _client;
  final Duration timeout;

  @override
  Future<AppRelease?> latest({required bool includePrereleases}) async {
    if (!includePrereleases) {
      // `/releases/latest` never returns drafts or pre-releases.
      final Object? release = await _get('$_releasesPath/latest', null);
      return release == null ? null : _parse(_asObject(release));
    }

    final Object? body = await _get(_releasesPath, <String, String>{
      'per_page': '$_pageSize',
    });
    if (body is! List<Object?>) {
      throw const UpdateResponseException('Release list is not a list');
    }
    final List<(AppVersion, Map<String, Object?>)> candidates =
        <(AppVersion, Map<String, Object?>)>[];
    for (final Object? item in body) {
      final Map<String, Object?> release = _asObject(item);
      if (release['draft'] == true) continue;
      final Object? tag = release['tag_name'];
      final AppVersion? version = tag is String
          ? AppVersion.tryParse(tag)
          : null;
      if (version != null) candidates.add((version, release));
    }
    candidates.sort(
      (
        (AppVersion, Map<String, Object?>) a,
        (AppVersion, Map<String, Object?>) b,
      ) => b.$1.compareTo(a.$1),
    );
    for (final (AppVersion _, Map<String, Object?> release) in candidates) {
      try {
        return _parse(release);
      } on UpdateResponseException {
        // The release workflow publishes a release before uploading its APK,
        // so the newest one can briefly have none; fall back to the next.
        continue;
      }
    }
    return null;
  }

  /// Returns the decoded body, or null on HTTP 404.
  Future<Object?> _get(String path, Map<String, String>? query) async {
    final http.Response response;
    try {
      response = await _client
          .get(
            Uri.https(_host, path, query),
            headers: <String, String>{
              'Accept': 'application/vnd.github+json',
              'X-GitHub-Api-Version': '2022-11-28',
              // GitHub rejects requests without a User-Agent.
              'User-Agent': 'AniHub',
            },
          )
          .timeout(timeout);
    } on TimeoutException {
      throw UpdateTimeoutException(timeout);
    } on http.ClientException catch (error) {
      throw UpdateNetworkException(error.message);
    } on IOException catch (error) {
      // TLS handshake failures escape IOClient without being wrapped.
      throw UpdateNetworkException('$error');
    }

    switch (response.statusCode) {
      case 200:
        break;
      case 404:
        return null;
      // GitHub answers an exhausted rate limit with 403 or 429.
      case 403 when response.headers['x-ratelimit-remaining'] == '0':
      case 429:
        throw const UpdateRateLimitException();
      default:
        throw UpdateResponseException(
          'GitHub answered HTTP ${response.statusCode}',
        );
    }

    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException catch (error) {
      throw UpdateResponseException('Unreadable response body: $error');
    }
  }

  static Map<String, Object?> _asObject(Object? value) {
    if (value is! Map<String, Object?>) {
      throw const UpdateResponseException('Release is not an object');
    }
    return value;
  }

  static AppRelease _parse(Map<String, Object?> release) {
    final Object? tag = release['tag_name'];
    final AppVersion? version = tag is String ? AppVersion.tryParse(tag) : null;
    final Uri? pageUrl = _uri(release['html_url']);
    if (version == null || pageUrl == null) {
      throw UpdateResponseException('Release $tag has no version or page');
    }

    final Object? assets = release['assets'];
    final List<Map<String, Object?>> apks = <Map<String, Object?>>[
      if (assets is List<Object?>)
        for (final Object? asset in assets)
          if (asset is Map<String, Object?> &&
              (asset['name'] as String?)?.endsWith('.apk') == true)
            asset,
    ];
    if (apks.length != 1) {
      throw UpdateResponseException(
        'Release $tag has ${apks.length} APKs instead of one',
      );
    }
    final Map<String, Object?> apk = apks.single;
    final Uri? apkUrl = _uri(apk['browser_download_url']);
    final Object? size = apk['size'];
    final Object? digest = apk['digest'];
    final RegExpMatch? sha256 = digest is String
        ? _sha256Digest.firstMatch(digest)
        : null;
    // Without a digest the download could not be verified.
    if (apkUrl == null || size is! int || sha256 == null) {
      throw UpdateResponseException('The APK of $tag cannot be verified');
    }
    return AppRelease(
      version: version,
      pageUrl: pageUrl,
      apkUrl: apkUrl,
      apkSha256: sha256[1]!,
      apkSize: size,
    );
  }

  static Uri? _uri(Object? value) {
    final Uri? uri = value is String ? Uri.tryParse(value) : null;
    return uri != null && uri.isScheme('https') ? uri : null;
  }
}
