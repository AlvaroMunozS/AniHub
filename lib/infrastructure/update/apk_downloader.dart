import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../../domain/entities/app_release.dart';
import '../../domain/errors/update_exception.dart';

/// Downloads the APK of a release and verifies its SHA-256.
class ApkDownloader {
  ApkDownloader(this._client, {required this.directory, required this.timeout});

  final http.Client _client;

  /// Where the APK is written, as `update.apk`, replacing any previous one.
  final Directory directory;

  /// Longest wait for the response or for the next chunk of the body, so a
  /// slow but steady download is never cut short.
  final Duration timeout;

  /// Downloads the APK of [release] and returns the verified file.
  ///
  /// [onProgress] receives the downloaded fraction, from 0 to 1. The file is
  /// deleted if the download fails. Throws [UpdateChecksumException] if the
  /// digest does not match, and [UpdateNetworkException],
  /// [UpdateTimeoutException] or [UpdateResponseException] if the download
  /// fails.
  Future<File> download(
    AppRelease release, {
    void Function(double progress)? onProgress,
  }) async {
    final File file = File(p.join(directory.path, 'update.apk'));
    final Digest digest;
    try {
      digest = await _write(release, file, onProgress);
    } on TimeoutException {
      await _delete(file);
      throw UpdateTimeoutException(timeout);
    } on http.ClientException catch (error) {
      await _delete(file);
      throw UpdateNetworkException(error.message);
    } on IOException catch (error) {
      // Covers TLS failures that escape IOClient, and a full disk.
      await _delete(file);
      throw UpdateNetworkException('$error');
    } on UpdateException {
      await _delete(file);
      rethrow;
    }
    if (digest.toString() != release.apkSha256) {
      await _delete(file);
      throw const UpdateChecksumException();
    }
    return file;
  }

  /// Streams the APK into [file], hashing it on the way.
  Future<Digest> _write(
    AppRelease release,
    File file,
    void Function(double progress)? onProgress,
  ) async {
    final http.StreamedResponse response = await _client
        .send(
          http.Request('GET', release.apkUrl)..headers['User-Agent'] = 'AniHub',
        )
        .timeout(timeout);
    if (response.statusCode != 200) {
      // Releases the connection, which an unread body would hold.
      await response.stream.listen(null).cancel();
      throw UpdateResponseException(
        'APK download answered HTTP ${response.statusCode}',
      );
    }

    final int total = response.contentLength ?? release.apkSize;
    late final Digest digest;
    final ByteConversionSink hasher = sha256.startChunkedConversion(
      ChunkedConversionSink<Digest>.withCallback(
        (List<Digest> digests) => digest = digests.single,
      ),
    );
    final IOSink sink = file.openWrite();
    int received = 0;
    try {
      await for (final List<int> chunk in response.stream.timeout(timeout)) {
        sink.add(chunk);
        hasher.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress?.call(min(received / total, 1));
      }
    } finally {
      await sink.close();
    }
    hasher.close();
    return digest;
  }

  static Future<void> _delete(File file) async {
    if (await file.exists()) await file.delete();
  }
}
