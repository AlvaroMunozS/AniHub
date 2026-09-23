import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../domain/errors/catalog_exception.dart';

/// HTTP transport for the public endpoints of the MyAnimeList API v2.
///
/// Public endpoints only need the app's client id, sent in the
/// `X-MAL-CLIENT-ID` header; no user token is involved.
class MalClient {
  MalClient(this._client, {required this.clientId, required this.timeout});

  static const String _host = 'api.myanimelist.net';

  final http.Client _client;
  final String clientId;
  final Duration timeout;

  /// Sends a GET to `/v2/[path]` and returns the decoded JSON object.
  ///
  /// Returns null on HTTP 404. Throws [CatalogUnauthorizedException] without a
  /// request when the client id is empty, and when the API rejects it.
  /// Other failures are thrown as [CatalogRateLimitException] (HTTP 429),
  /// [CatalogTimeoutException], [CatalogNetworkException] or
  /// [CatalogResponseException].
  Future<Map<String, Object?>?> get(
    String path,
    Map<String, String> query,
  ) async {
    if (clientId.isEmpty) {
      throw const CatalogUnauthorizedException('MAL_CLIENT_ID is not set');
    }

    final http.Response response;
    try {
      response = await _client
          .get(
            Uri.https(_host, '/v2/$path', query),
            headers: <String, String>{
              'X-MAL-CLIENT-ID': clientId,
              'Accept': 'application/json',
            },
          )
          .timeout(timeout);
    } on TimeoutException {
      throw CatalogTimeoutException(timeout);
    } on http.ClientException catch (error) {
      throw CatalogNetworkException(error.message);
    } on IOException catch (error) {
      // TLS handshake failures escape IOClient without being wrapped.
      throw CatalogNetworkException('$error');
    }

    switch (response.statusCode) {
      case 200:
        break;
      case 404:
        return null;
      case 429:
        throw CatalogRateLimitException(
          retryAfter: _parseRetryAfter(response.headers['retry-after']),
        );
      // MyAnimeList answers an unknown client id with HTTP 400, not 401.
      case 400 when response.body.contains('Invalid client id'):
      case 401:
        throw CatalogUnauthorizedException(
          'MyAnimeList rejected the client id (HTTP ${response.statusCode})',
        );
      default:
        throw CatalogResponseException(
          'MyAnimeList answered HTTP ${response.statusCode}',
        );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException catch (error) {
      throw CatalogResponseException('Unreadable response body: $error');
    }
    if (decoded is! Map<String, Object?>) {
      throw const CatalogResponseException('Response body is not an object');
    }
    return decoded;
  }

  // Only the delta-seconds form of `Retry-After` is honored.
  static Duration? _parseRetryAfter(String? raw) {
    final int? seconds = raw == null ? null : int.tryParse(raw.trim());
    return seconds == null || seconds < 0 ? null : Duration(seconds: seconds);
  }
}
