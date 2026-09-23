import 'package:flutter/material.dart';

import '../domain/errors/catalog_exception.dart';

/// Shown instead of a connection error when the app was built without a
/// valid MyAnimeList client id, since retrying cannot help.
const String catalogUnauthorizedMessage =
    'Esta versión de la app no tiene un Client ID de MyAnimeList válido.';

/// Retry hint for a failure that is not about the connection.
const String retryLaterMessage = 'Inténtalo de nuevo en unos segundos.';

const String _networkMessage = 'Revisa la conexión e inténtalo otra vez.';

/// Describes a failed catalog request to the user.
///
/// [error] is usually a [CatalogException]; anything else is a bug, which
/// gets [retryLaterMessage] and must be reported by whoever caught it.
String catalogErrorMessage(Object error) {
  return switch (error) {
    CatalogRateLimitException(:final Duration? retryAfter)
        when retryAfter != null && retryAfter.inSeconds > 1 =>
      'Demasiadas peticiones a MyAnimeList; espera unos '
          '${retryAfter.inSeconds} segundos.',
    CatalogRateLimitException() =>
      'Demasiadas peticiones a MyAnimeList; espera unos segundos.',
    CatalogTimeoutException() || CatalogNetworkException() => _networkMessage,
    CatalogUnauthorizedException() => catalogUnauthorizedMessage,
    CatalogResponseException() =>
      'MyAnimeList no devolvió datos válidos. $retryLaterMessage',
    _ => retryLaterMessage,
  };
}

/// Icon for [catalogErrorMessage]: a connection icon only when the
/// connection is the problem.
IconData catalogErrorIcon(Object error) {
  return switch (error) {
    CatalogTimeoutException() ||
    CatalogNetworkException() => Icons.cloud_off_outlined,
    _ => Icons.error_outline,
  };
}
