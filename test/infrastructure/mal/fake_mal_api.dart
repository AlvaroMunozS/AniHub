import 'dart:convert';

import 'package:anihub/infrastructure/mal/mal_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A fake MyAnimeList API that records every request and answers it with
/// [respond].
class FakeMalApi {
  FakeMalApi(this.respond);

  /// Answers the requests in order with [responses].
  factory FakeMalApi.sequence(List<http.Response> responses) {
    int next = 0;
    return FakeMalApi((_) async => responses[next++]);
  }

  final Future<http.Response> Function(Uri url) respond;
  final List<Uri> requests = <Uri>[];
  final List<Map<String, String>> headers = <Map<String, String>>[];

  MalClient client({
    String clientId = 'test-id',
    Duration timeout = const Duration(seconds: 1),
  }) => MalClient(
    MockClient((http.Request request) {
      requests.add(request.url);
      headers.add(request.headers);
      return respond(request.url);
    }),
    clientId: clientId,
    timeout: timeout,
  );
}

http.Response jsonResponse(Object? body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status);
