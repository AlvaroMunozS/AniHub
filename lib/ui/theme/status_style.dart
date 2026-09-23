import 'package:flutter/material.dart' show IconData, Icons;
import 'package:flutter/widgets.dart';

import '../../domain/values/watch_status.dart';
import '../../l10n/l10n.dart';
import 'tokens.dart';

String statusLabel(AppLocalizations l10n, WatchStatus status) {
  switch (status) {
    case WatchStatus.watching:
      return l10n.statusWatching;
    case WatchStatus.planned:
      return l10n.statusPlanned;
    case WatchStatus.completed:
      return l10n.statusCompleted;
  }
}

Color statusColor(AppPalette palette, WatchStatus status) {
  switch (status) {
    case WatchStatus.watching:
      return palette.statusWatching;
    case WatchStatus.planned:
      return palette.statusPlanned;
    case WatchStatus.completed:
      return palette.statusCompleted;
  }
}

/// Returns the filled icon for [status] when [selected], otherwise the
/// outlined one.
IconData statusIcon(WatchStatus status, {required bool selected}) {
  switch (status) {
    case WatchStatus.watching:
      return selected ? Icons.visibility : Icons.visibility_outlined;
    case WatchStatus.planned:
      return selected ? Icons.schedule : Icons.schedule_outlined;
    case WatchStatus.completed:
      return selected ? Icons.check_circle : Icons.check_circle_outline;
  }
}
