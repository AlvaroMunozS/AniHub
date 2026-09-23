import 'package:flutter/material.dart';

import '../domain/errors/catalog_exception.dart';
import '../l10n/l10n.dart';

/// Describes a failed catalog request to the user.
///
/// [error] is usually a [CatalogException]; anything else is a bug, which
/// gets [AppLocalizations.catalogRetryLater] and must be reported by whoever
/// caught it. A missing client id gets its own message instead of a
/// connection error, since retrying cannot help.
String catalogErrorMessage(AppLocalizations l10n, Object error) {
  return switch (error) {
    CatalogRateLimitException(:final Duration? retryAfter)
        when retryAfter != null && retryAfter.inSeconds > 1 =>
      l10n.catalogRateLimitedFor(retryAfter.inSeconds),
    CatalogRateLimitException() => l10n.catalogRateLimited,
    CatalogTimeoutException() ||
    CatalogNetworkException() => l10n.catalogNetwork,
    CatalogUnauthorizedException() => l10n.catalogUnauthorized,
    CatalogResponseException() => l10n.catalogInvalidResponse,
    _ => l10n.catalogRetryLater,
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
