import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/entry.dart';
import '../../domain/values/watch_status.dart';
import '../../l10n/l10n.dart';
import '../state/library_providers.dart';

/// Sets the status of [entry] through [PendingEntryChanges], showing a
/// [SnackBar] if the write fails.
Future<void> changeStatus(
  WidgetRef ref,
  BuildContext context,
  Entry entry,
  WatchStatus status,
) {
  return _withFailureMessage(
    context,
    ref.read(pendingEntryChangesProvider.notifier).changeStatus(entry, status),
    context.l10n.entryUpdateFailed,
  );
}

/// Toggles the favorite flag of [entry] through [PendingEntryChanges],
/// showing a [SnackBar] if the write fails.
Future<void> toggleFavorite(WidgetRef ref, BuildContext context, Entry entry) {
  return _withFailureMessage(
    context,
    ref.read(pendingEntryChangesProvider.notifier).toggleFavorite(entry),
    context.l10n.entryUpdateFailed,
  );
}

/// Removes [entry] through [PendingEntryChanges], showing a [SnackBar] if the
/// delete fails.
///
/// Returns whether the entry was removed.
Future<bool> removeFromLibrary(
  WidgetRef ref,
  BuildContext context,
  Entry entry,
) async {
  final ChangeOutcome outcome = await _withFailureMessage(
    context,
    ref.read(pendingEntryChangesProvider.notifier).remove(entry),
    context.l10n.entryRemoveFailed,
  );
  return outcome == ChangeOutcome.applied;
}

/// Shows [message] only when [change] fails; an ignored change, such as a
/// repeated tap while a write is in flight, is silent.
Future<ChangeOutcome> _withFailureMessage(
  BuildContext context,
  Future<ChangeOutcome> change,
  String message,
) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final ChangeOutcome outcome = await change;
  if (outcome == ChangeOutcome.failed) {
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
  return outcome;
}
