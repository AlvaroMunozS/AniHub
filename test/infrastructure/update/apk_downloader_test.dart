import 'dart:async';
import 'dart:io';

import 'package:anihub/domain/entities/app_release.dart';
import 'package:anihub/domain/errors/update_exception.dart';
import 'package:anihub/domain/values/app_version.dart';
import 'package:anihub/infrastructure/update/apk_downloader.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final List<List<int>> _chunks = <List<int>>[
  List<int>.filled(30, 1),
  List<int>.filled(70, 2),
];
final List<int> _bytes = _chunks.expand((List<int> c) => c).toList();

AppRelease _release({String? sha256Hex}) => AppRelease(
  version: AppVersion.tryParse('1.1.0')!,
  pageUrl: Uri.parse('https://github.com/o/r/releases/tag/v1.1.0'),
  apkUrl: Uri.parse('https://github.com/o/r/releases/download/v1.1.0/a.apk'),
  apkSha256: sha256Hex ?? sha256.convert(_bytes).toString(),
  apkSize: _bytes.length,
);

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('anihub_update_test');
    addTearDown(() => directory.delete(recursive: true));
  });

  ApkDownloader downloader(
    Future<http.StreamedResponse> Function(http.BaseRequest request) respond, {
    Duration timeout = const Duration(seconds: 1),
  }) => ApkDownloader(
    MockClient.streaming(
      (http.BaseRequest request, http.ByteStream _) => respond(request),
    ),
    directory: directory,
    timeout: timeout,
  );

  File apkFile() =>
      File('${directory.path}${Platform.pathSeparator}update.apk');

  test('writes the verified APK and reports progress', () async {
    final List<double> progress = <double>[];
    late http.BaseRequest sent;

    final File file = await downloader((http.BaseRequest request) async {
      sent = request;
      return http.StreamedResponse(
        Stream<List<int>>.fromIterable(_chunks),
        200,
        contentLength: _bytes.length,
      );
    }).download(_release(), onProgress: progress.add);

    expect(await file.readAsBytes(), _bytes);
    expect(progress, <double>[0.3, 1]);
    expect(sent.url.path, endsWith('/a.apk'));
    expect(sent.headers['User-Agent'], 'AniHub');
  });

  test('falls back to the release size without a content length', () async {
    final List<double> progress = <double>[];

    await downloader(
      (_) async =>
          http.StreamedResponse(Stream<List<int>>.fromIterable(_chunks), 200),
    ).download(_release(), onProgress: progress.add);

    expect(progress, <double>[0.3, 1]);
  });

  test('deletes the file when the digest does not match', () async {
    await expectLater(
      downloader(
        (_) async =>
            http.StreamedResponse(Stream<List<int>>.fromIterable(_chunks), 200),
      ).download(_release(sha256Hex: '0' * 64)),
      throwsA(isA<UpdateChecksumException>()),
    );
    expect(apkFile().existsSync(), isFalse);
  });

  test('rejects an unexpected status', () async {
    await expectLater(
      downloader(
        (_) async =>
            http.StreamedResponse(const Stream<List<int>>.empty(), 404),
      ).download(_release()),
      throwsA(isA<UpdateResponseException>()),
    );
    expect(apkFile().existsSync(), isFalse);
  });

  test('deletes the partial file when the connection drops', () async {
    final StreamController<List<int>> body = StreamController<List<int>>();
    body
      ..add(_chunks.first)
      ..addError(http.ClientException('connection reset'));
    unawaited(body.close());

    await expectLater(
      downloader((_) async => http.StreamedResponse(body.stream, 200))
          .download(_release()),
      throwsA(isA<UpdateNetworkException>()),
    );
    expect(apkFile().existsSync(), isFalse);
  });

  test('gives up when the body stalls', () async {
    final StreamController<List<int>> body = StreamController<List<int>>();
    addTearDown(body.close);
    body.add(_chunks.first);

    await expectLater(
      downloader(
        (_) async => http.StreamedResponse(body.stream, 200),
        timeout: const Duration(milliseconds: 50),
      ).download(_release()),
      throwsA(isA<UpdateTimeoutException>()),
    );
    expect(apkFile().existsSync(), isFalse);
  });
}
