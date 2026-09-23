/// A failure of a catalog request.
///
/// An empty result is not a failure: searches return an empty list instead.
sealed class CatalogException implements Exception {
  const CatalogException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// The catalog rejected the request with HTTP 429.
///
/// [retryAfter] is taken from the `Retry-After` header when the server sends
/// one.
class CatalogRateLimitException extends CatalogException {
  const CatalogRateLimitException({this.retryAfter})
    : super('Rate limit exceeded (HTTP 429)');

  final Duration? retryAfter;
}

/// The request did not complete within [timeout].
class CatalogTimeoutException extends CatalogException {
  CatalogTimeoutException(this.timeout)
    : super('No response within ${timeout.inSeconds}s');

  final Duration timeout;
}

/// The response had an unexpected status, an unreadable body or malformed
/// data.
class CatalogResponseException extends CatalogException {
  const CatalogResponseException(super.message);
}

/// The app has no valid catalog credentials, so no request can succeed until
/// it is rebuilt with them.
class CatalogUnauthorizedException extends CatalogException {
  const CatalogUnauthorizedException(super.message);
}

/// The request failed before any response arrived, for example because of
/// missing connectivity or a DNS failure.
class CatalogNetworkException extends CatalogException {
  const CatalogNetworkException(super.message);
}
