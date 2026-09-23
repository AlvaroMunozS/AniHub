import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:anihub/domain/errors/catalog_exception.dart';
import 'package:anihub/infrastructure/mal/mal_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'fake_mal_api.dart';

MalClient _client(
  Future<http.Response> Function(Uri url) respond, {
  String clientId = 'test-id',
  Duration timeout = const Duration(seconds: 1),
}) => FakeMalApi(respond).client(clientId: clientId, timeout: timeout);

void main() {
  test('sends the client id to the v2 endpoint', () async {
    final FakeMalApi api = FakeMalApi(
      (_) async => http.Response('{"id":1}', 200),
    );

    final Map<String, Object?>? body = await api.client().get(
      'anime/1',
      <String, String>{'fields': 'title'},
    );

    expect(body, <String, Object?>{'id': 1});
    expect(
      api.requests.single.toString(),
      'https://api.myanimelist.net/v2/anime/1?fields=title',
    );
    expect(api.headers.single['X-MAL-CLIENT-ID'], 'test-id');
  });

  test('decodes the body as UTF-8 without a charset header', () async {
    final MalClient client = _client(
      (_) async => http.Response.bytes(utf8.encode('{"title":"Sōsō"}'), 200),
    );

    expect(
      await client.get('anime/1', const <String, String>{}),
      <String, Object?>{'title': 'Sōsō'},
    );
  });

  test('returns null on HTTP 404', () async {
    final MalClient client = _client(
      (_) async => http.Response('{"error":"not_found"}', 404),
    );

    expect(await client.get('anime/1', const <String, String>{}), isNull);
  });

  test('throws without a request when the client id is empty', () async {
    int requests = 0;
    final MalClient client = _client((_) async {
      requests++;
      return http.Response('{}', 200);
    }, clientId: '');

    await expectLater(
      client.get('anime/1', const <String, String>{}),
      throwsA(isA<CatalogUnauthorizedException>()),
    );
    expect(requests, 0);
  });

  test('throws unauthorized when the client id is rejected', () async {
    final MalClient client = _client(
      (_) async => http.Response(
        '{"message":"Invalid client id","error":"bad_request"}',
        400,
      ),
    );

    await expectLater(
      client.get('anime/1', const <String, String>{}),
      throwsA(isA<CatalogUnauthorizedException>()),
    );
  });

  test('throws unauthorized on HTTP 401', () async {
    final MalClient client = _client((_) async => http.Response('', 401));

    await expectLater(
      client.get('anime/1', const <String, String>{}),
      throwsA(isA<CatalogUnauthorizedException>()),
    );
  });

  test('reports other HTTP 400 answers as a response error', () async {
    final MalClient client = _client(
      (_) async =>
          http.Response('{"message":"invalid q","error":"bad_request"}', 400),
    );

    await expectLater(
      client.get('anime', const <String, String>{}),
      throwsA(isA<CatalogResponseException>()),
    );
  });

  test('reads Retry-After seconds on HTTP 429', () async {
    final MalClient client = _client(
      (_) async =>
          http.Response('', 429, headers: <String, String>{'retry-after': '7'}),
    );

    await expectLater(
      client.get('anime/1', const <String, String>{}),
      throwsA(
        isA<CatalogRateLimitException>().having(
          (CatalogRateLimitException e) => e.retryAfter,
          'retryAfter',
          const Duration(seconds: 7),
        ),
      ),
    );
  });

  test('ignores a Retry-After date on HTTP 429', () async {
    final MalClient client = _client(
      (_) async => http.Response(
        '',
        429,
        headers: <String, String>{
          'retry-after': 'Wed, 21 Oct 2015 07:28:00 GMT',
        },
      ),
    );

    await expectLater(
      client.get('anime/1', const <String, String>{}),
      throwsA(
        isA<CatalogRateLimitException>().having(
          (CatalogRateLimitException e) => e.retryAfter,
          'retryAfter',
          isNull,
        ),
      ),
    );
  });

  test('reports a server error as a response error', () async {
    final MalClient client = _client((_) async => http.Response('', 500));

    await expectLater(
      client.get('anime/1', const <String, String>{}),
      throwsA(isA<CatalogResponseException>()),
    );
  });

  test(
    'reports a body that is not a JSON object as a response error',
    () async {
      for (final String body in <String>['not json', '[1, 2]']) {
        final MalClient client = _client((_) async => http.Response(body, 200));

        await expectLater(
          client.get('anime/1', const <String, String>{}),
          throwsA(isA<CatalogResponseException>()),
          reason: body,
        );
      }
    },
  );

  test('reports a transport failure as a network error', () async {
    final MalClient client = _client(
      (_) async => throw http.ClientException('connection refused'),
    );

    await expectLater(
      client.get('anime/1', const <String, String>{}),
      throwsA(isA<CatalogNetworkException>()),
    );
  });

  test('reports a TLS failure as a network error', () async {
    final MalClient client = _client(
      (_) async => throw const HandshakeException('bad certificate'),
    );

    await expectLater(
      client.get('anime/1', const <String, String>{}),
      throwsA(isA<CatalogNetworkException>()),
    );
  });

  test('reports a request that never answers as a timeout', () async {
    final MalClient client = _client(
      (_) => Completer<http.Response>().future,
      timeout: Duration.zero,
    );

    await expectLater(
      client.get('anime/1', const <String, String>{}),
      throwsA(isA<CatalogTimeoutException>()),
    );
  });
}
