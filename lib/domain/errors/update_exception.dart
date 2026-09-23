/// A failure while checking for, downloading or installing an update.
sealed class UpdateException implements Exception {
  const UpdateException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// The request failed before any response arrived, for example because of
/// missing connectivity or a DNS failure.
class UpdateNetworkException extends UpdateException {
  const UpdateNetworkException(super.message);
}

/// The server stopped answering for longer than [timeout].
class UpdateTimeoutException extends UpdateException {
  UpdateTimeoutException(this.timeout)
    : super('No response within ${timeout.inSeconds}s');

  final Duration timeout;
}

/// The release source refused more requests for now.
class UpdateRateLimitException extends UpdateException {
  const UpdateRateLimitException() : super('Rate limit exceeded');
}

/// The response had an unexpected status, an unreadable body or a release
/// without a verifiable APK.
class UpdateResponseException extends UpdateException {
  const UpdateResponseException(super.message);
}

/// The downloaded APK does not match the digest of the release.
class UpdateChecksumException extends UpdateException {
  const UpdateChecksumException() : super('APK digest mismatch');
}

/// The system installer rejected the APK or could not start.
class UpdateInstallException extends UpdateException {
  const UpdateInstallException(super.message);
}
