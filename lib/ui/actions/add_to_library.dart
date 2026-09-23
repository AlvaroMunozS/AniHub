import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/catalog_anime.dart';
import '../../domain/errors/duplicate_entry_exception.dart';
import '../../domain/values/watch_status.dart';
import '../../l10n/l10n.dart';
import '../providers.dart';
import '../report_error.dart';
import '../theme/status_style.dart';

/// Tracks the MyAnimeList ids with an add in flight, so repeated taps on the
/// same anime write once.
class PendingAdds extends Notifier<Set<int>> {
  @override
  Set<int> build() => const <int>{};

  void add(int malId) {
    state = <int>{...state, malId};
  }

  void remove(int malId) {
    final Set<int> next = Set<int>.of(state)..remove(malId);
    state = next;
  }
}

final NotifierProvider<PendingAdds, Set<int>> pendingAddsProvider =
    NotifierProvider<PendingAdds, Set<int>>(PendingAdds.new);

/// Adds [anime] to the library and reports the outcome in a [SnackBar].
///
/// Does nothing while an add for the same anime is in flight (see
/// [pendingAddsProvider]). A [DuplicateEntryException] counts as success;
/// any other error is reported and shows a failure message instead of
/// propagating.
Future<void> addToLibrary(
  WidgetRef ref,
  BuildContext context,
  CatalogAnime anime, {
  WatchStatus status = WatchStatus.planned,
  bool isFavorite = false,
}) async {
  final int malId = anime.malId;
  if (ref.read(pendingAddsProvider).contains(malId)) {
    return;
  }
  final PendingAdds pending = ref.read(pendingAddsProvider.notifier);
  pending.add(malId);
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final AppLocalizations l10n = context.l10n;
  try {
    await ref.read(addEntryProvider)(
      anime,
      status: status,
      isFavorite: isFavorite,
    );
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          isFavorite
              ? l10n.entryAddedAsFavorite(statusLabel(l10n, status))
              : l10n.entryAdded(statusLabel(l10n, status)),
        ),
      ),
    );
  } on DuplicateEntryException {
    // Added concurrently since the caller last read the library; the entry
    // exists, which is the outcome the user asked for.
  } on Object catch (error, stack) {
    reportUiError(error, stack);
    messenger.showSnackBar(SnackBar(content: Text(l10n.entryAddFailed)));
  } finally {
    pending.remove(malId);
  }
}
