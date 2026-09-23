import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/usecases/usecases.dart';
import '../../domain/entities/catalog_anime.dart';
import '../../domain/values/watch_status.dart';
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
              ? 'Añadido a «${statusLabel(status)}» y a favoritos'
              : 'Añadido a «${statusLabel(status)}»',
        ),
      ),
    );
  } on DuplicateEntryException {
    // Added concurrently since the caller last read the library; the entry
    // exists, which is the outcome the user asked for.
  } on Object catch (error, stack) {
    reportUiError(error, stack);
    messenger.showSnackBar(const SnackBar(content: Text('No se pudo añadir')));
  } finally {
    pending.remove(malId);
  }
}
