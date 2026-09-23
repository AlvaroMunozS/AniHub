import 'package:flutter/foundation.dart';

/// Reports an unexpected [error] that the UI recovers from, so it still
/// reaches the logs while the user sees a message or a rollback.
void reportUiError(Object error, StackTrace stack) {
  FlutterError.reportError(
    FlutterErrorDetails(exception: error, stack: stack, library: 'anihub ui'),
  );
}

/// Completes like [future], first reporting through [reportUiError] any
/// error that [isExpected] rejects.
///
/// For providers whose errors the UI shows or hides without catching them,
/// so an unexpected one still reaches the logs.
Future<T> reportingUnexpected<T>(
  Future<T> future, {
  required bool Function(Object error) isExpected,
}) async {
  try {
    return await future;
  } on Object catch (error, stack) {
    if (!isExpected(error)) reportUiError(error, stack);
    rethrow;
  }
}
