import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderFamily;
import 'package:shared_preferences/shared_preferences.dart';

import '../../application/usecases/usecases.dart';
import '../../domain/entities/anime_relation_node.dart';
import '../../domain/entities/entry.dart';
import '../../domain/errors/catalog_exception.dart';
import '../../domain/values/watch_status.dart';
import '../providers.dart';
import '../report_error.dart';

final StreamProvider<List<Entry>> libraryEntriesProvider =
    StreamProvider<List<Entry>>(
      (Ref ref) => reportingErrors(ref.watch(listEntriesProvider)()),
    );

/// Relation graph of the whole library rather than one tab, because seasons
/// of a franchise can sit in different statuses.
///
/// Watches the ids as a sorted, comma-joined [String]: Riverpod compares
/// selected values with `==`, and a new `List<int>` never equals the previous
/// one, which would refetch the graph on every library write.
///
/// The port returns what it could fetch when a large lookup fails part way,
/// so a graph that lacks some ids is fetched again after [retryDelays]; ids
/// already fetched come from the cache. An id the catalog does not know is
/// also absent, which is why the retries are capped.
class LibraryRelations extends AsyncNotifier<Map<int, AnimeRelationNode>> {
  static const List<Duration> retryDelays = <Duration>[
    Duration(minutes: 1),
    Duration(minutes: 5),
    Duration(minutes: 15),
  ];

  // The notifier outlives rebuilds, so the count survives the retries it
  // triggers and restarts when the ids change.
  String _idsKey = '';
  int _retries = 0;

  @override
  Future<Map<int, AnimeRelationNode>> build() async {
    final String idsKey = ref.watch(
      libraryEntriesProvider.select(_libraryIdsKey),
    );
    if (idsKey != _idsKey) {
      _idsKey = idsKey;
      _retries = 0;
    }
    if (idsKey.isEmpty) return const <int, AnimeRelationNode>{};
    final List<int> ids = idsKey.split(',').map(int.parse).toList();
    final Map<int, AnimeRelationNode> graph = await reportingUnexpected(
      ref.watch(animeRelationsProvider).forIds(ids),
      isExpected: (Object error) => error is CatalogException,
    );
    if (ref.mounted &&
        _retries < retryDelays.length &&
        !ids.every(graph.containsKey)) {
      final Timer retry = Timer(retryDelays[_retries++], ref.invalidateSelf);
      ref.onDispose(retry.cancel);
    }
    return graph;
  }
}

final AsyncNotifierProvider<LibraryRelations, Map<int, AnimeRelationNode>>
libraryRelationsProvider =
    AsyncNotifierProvider<LibraryRelations, Map<int, AnimeRelationNode>>(
      LibraryRelations.new,
    );

String _libraryIdsKey(AsyncValue<List<Entry>> value) {
  final List<Entry>? entries = value.asData?.value;
  if (entries == null || entries.isEmpty) return '';
  return (entries.map((Entry e) => e.malId).toList()..sort()).join(',');
}

/// An optimistic change to an entry whose write has not completed: a new
/// status, a new favorite flag, a removal, or a combination.
class EntryPatch {
  const EntryPatch({this.status, this.isFavorite, this.removed = false});

  final WatchStatus? status;
  final bool? isFavorite;
  final bool removed;

  bool get isEmpty => status == null && isFavorite == null && !removed;

  EntryPatch copyWith({WatchStatus? status, bool? isFavorite, bool? removed}) {
    return EntryPatch(
      status: status ?? this.status,
      isFavorite: isFavorite ?? this.isFavorite,
      removed: removed ?? this.removed,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is EntryPatch &&
      other.status == status &&
      other.isFavorite == isFavorite &&
      other.removed == removed;

  @override
  int get hashCode => Object.hash(status, isFavorite, removed);

  @override
  String toString() =>
      'EntryPatch(status: $status, isFavorite: $isFavorite, removed: $removed)';
}

/// Result of a change requested through [PendingEntryChanges].
enum ChangeOutcome {
  /// The write completed.
  applied,

  /// Nothing was written: the entry is unsaved, the change is a no-op, or
  /// another change to the entry is in flight.
  ignored,

  /// The write failed and the optimistic change was rolled back.
  failed,
}

/// Pending optimistic changes, keyed by entry id.
///
/// Every screen reads them through [visibleLibraryEntriesProvider], so a
/// change made on one screen shows on all of them at once. Patches keep a
/// favorite completed, like the use cases they stand in for. A failed write
/// is rolled back and reported through [FlutterError.reportError].
class PendingEntryChanges extends Notifier<Map<String, EntryPatch>> {
  /// Ids with a write in flight; further changes to them are ignored until
  /// it settles.
  final Set<String> _inFlight = <String>{};

  @override
  Map<String, EntryPatch> build() {
    // Drops each patch field once the stream confirms it. Removals are kept
    // until the entry leaves the stream.
    ref.listen<AsyncValue<List<Entry>>>(libraryEntriesProvider, (
      AsyncValue<List<Entry>>? previous,
      AsyncValue<List<Entry>> next,
    ) {
      final List<Entry>? entries = next.asData?.value;
      if (entries == null || state.isEmpty) return;
      final Map<String, Entry> byId = <String, Entry>{
        for (final Entry e in entries)
          if (e.id != null) e.id!: e,
      };
      final Map<String, EntryPatch> updated = <String, EntryPatch>{};
      state.forEach((String id, EntryPatch patch) {
        final Entry? real = byId[id];
        if (patch.removed) {
          if (real != null) updated[id] = patch;
          return;
        }
        if (real == null) {
          return;
        }
        final EntryPatch cleared = EntryPatch(
          status: patch.status == real.status ? null : patch.status,
          isFavorite: patch.isFavorite == real.isFavorite
              ? null
              : patch.isFavorite,
        );
        if (!cleared.isEmpty) updated[id] = cleared;
      });
      if (!mapEquals(updated, state)) {
        state = updated;
      }
    });
    return const <String, EntryPatch>{};
  }

  void _apply(String id, EntryPatch Function(EntryPatch current) update) {
    final EntryPatch current = state[id] ?? const EntryPatch();
    state = <String, EntryPatch>{...state, id: update(current)};
  }

  /// Rolls back a failed change, dropping the patch once nothing is left.
  void _revert(String id, EntryPatch Function(EntryPatch current) clear) {
    final EntryPatch? current = state[id];
    if (current == null) return;
    final EntryPatch reverted = clear(current);
    final Map<String, EntryPatch> updated = Map<String, EntryPatch>.of(state);
    if (reverted.isEmpty) {
      updated.remove(id);
    } else {
      updated[id] = reverted;
    }
    state = updated;
  }

  /// Applies [status] optimistically and writes it through [ChangeStatus].
  ///
  /// Moving a favorite out of [WatchStatus.completed] also clears the
  /// favorite in the same patch, mirroring [ChangeStatus]. Ignores an
  /// unchanged status.
  Future<ChangeOutcome> changeStatus(Entry entry, WatchStatus status) async {
    final String? id = entry.id;
    if (id == null || status == entry.status || _inFlight.contains(id)) {
      return ChangeOutcome.ignored;
    }
    final bool clearsFavorite =
        entry.isFavorite && status != WatchStatus.completed;
    _inFlight.add(id);
    _apply(
      id,
      (EntryPatch p) => p.copyWith(
        status: status,
        isFavorite: clearsFavorite ? false : p.isFavorite,
      ),
    );
    try {
      await ref.read(changeStatusProvider)(entry, status);
      return ChangeOutcome.applied;
    } on Object catch (error, stack) {
      reportUiError(error, stack);
      _revert(
        id,
        (EntryPatch p) => clearsFavorite
            ? const EntryPatch()
            : EntryPatch(isFavorite: p.isFavorite),
      );
      return ChangeOutcome.failed;
    } finally {
      _inFlight.remove(id);
    }
  }

  /// Flips the favorite flag optimistically and writes it through
  /// [SetFavorite].
  ///
  /// Favoriting an entry that is not completed also completes it in the same
  /// patch, mirroring [SetFavorite].
  Future<ChangeOutcome> toggleFavorite(Entry entry) async {
    final String? id = entry.id;
    if (id == null || _inFlight.contains(id)) {
      return ChangeOutcome.ignored;
    }
    final bool desired = !entry.isFavorite;
    final bool forceCompleted =
        desired && entry.status != WatchStatus.completed;
    _inFlight.add(id);
    _apply(
      id,
      (EntryPatch p) => p.copyWith(
        isFavorite: desired,
        status: forceCompleted ? WatchStatus.completed : p.status,
      ),
    );
    try {
      await ref.read(setFavoriteProvider)(entry, isFavorite: desired);
      return ChangeOutcome.applied;
    } on Object catch (error, stack) {
      reportUiError(error, stack);
      _revert(
        id,
        (EntryPatch p) =>
            forceCompleted ? const EntryPatch() : EntryPatch(status: p.status),
      );
      return ChangeOutcome.failed;
    } finally {
      _inFlight.remove(id);
    }
  }

  /// Hides [entry] optimistically and deletes it through [RemoveEntry].
  Future<ChangeOutcome> remove(Entry entry) async {
    final String? id = entry.id;
    if (id == null || _inFlight.contains(id)) {
      return ChangeOutcome.ignored;
    }
    _inFlight.add(id);
    _apply(id, (EntryPatch p) => p.copyWith(removed: true));
    try {
      await ref.read(removeEntryProvider)(id);
      return ChangeOutcome.applied;
    } on Object catch (error, stack) {
      reportUiError(error, stack);
      _revert(
        id,
        (EntryPatch p) =>
            EntryPatch(status: p.status, isFavorite: p.isFavorite),
      );
      return ChangeOutcome.failed;
    } finally {
      _inFlight.remove(id);
    }
  }
}

final NotifierProvider<PendingEntryChanges, Map<String, EntryPatch>>
pendingEntryChangesProvider =
    NotifierProvider<PendingEntryChanges, Map<String, EntryPatch>>(
      PendingEntryChanges.new,
    );

/// [libraryEntriesProvider] with the pending patches applied.
///
/// Tab filtering and grouping read from here rather than from the raw
/// stream, so a card leaves its tab as soon as its status or favorite flag
/// changes. [libraryRelationsProvider] stays on the raw stream so optimistic
/// changes do not recompute the graph.
final Provider<AsyncValue<List<Entry>>> visibleLibraryEntriesProvider =
    Provider<AsyncValue<List<Entry>>>((Ref ref) {
      final AsyncValue<List<Entry>> raw = ref.watch(libraryEntriesProvider);
      final Map<String, EntryPatch> patches = ref.watch(
        pendingEntryChangesProvider,
      );
      if (patches.isEmpty) return raw;
      return raw.whenData((List<Entry> entries) {
        return <Entry>[
          for (final Entry entry in entries)
            if (entry.id == null || !patches.containsKey(entry.id))
              entry
            else if (!patches[entry.id]!.removed)
              entry.copyWith(
                status: patches[entry.id]!.status,
                isFavorite: patches[entry.id]!.isFavorite,
              ),
        ];
      });
    });

class LibrarySort {
  const LibrarySort({
    this.order = LibraryOrder.alphabetical,
    this.reversed = false,
  });

  final LibraryOrder order;
  final bool reversed;

  LibrarySort copyWith({LibraryOrder? order, bool? reversed}) {
    return LibrarySort(
      order: order ?? this.order,
      reversed: reversed ?? this.reversed,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LibrarySort &&
      other.order == order &&
      other.reversed == reversed;

  @override
  int get hashCode => Object.hash(order, reversed);
}

const String _orderPrefsKey = 'library.order';
const String _orderReversedPrefsKey = 'library.order.reversed';

/// Persists the library sort in [SharedPreferences].
class LibraryOrderNotifier extends Notifier<LibrarySort> {
  @override
  LibrarySort build() {
    final SharedPreferences prefs = ref.watch(sharedPreferencesProvider);
    final String? storedOrder = prefs.getString(_orderPrefsKey);
    final LibraryOrder order = LibraryOrder.values.firstWhere(
      (LibraryOrder o) => o.name == storedOrder,
      orElse: () => LibraryOrder.alphabetical,
    );
    return LibrarySort(
      order: order,
      reversed: prefs.getBool(_orderReversedPrefsKey) ?? false,
    );
  }

  /// Selects [order] in its default direction, or reverses the direction if
  /// [order] is already selected.
  void select(LibraryOrder order) {
    state = order == state.order
        ? state.copyWith(reversed: !state.reversed)
        : LibrarySort(order: order);
    final SharedPreferences prefs = ref.read(sharedPreferencesProvider);
    unawaited(prefs.setString(_orderPrefsKey, state.order.name));
    unawaited(prefs.setBool(_orderReversedPrefsKey, state.reversed));
  }
}

final NotifierProvider<LibraryOrderNotifier, LibrarySort> libraryOrderProvider =
    NotifierProvider<LibraryOrderNotifier, LibrarySort>(
      LibraryOrderNotifier.new,
    );

class LibraryFilter {
  const LibraryFilter({this.query = '', this.onlyFavorites = false});

  final String query;
  final bool onlyFavorites;

  /// The filter as applied to the [status] tab.
  ///
  /// Only completed entries can be favorites, so the favorites filter
  /// applies to the completed tab alone.
  LibraryFilter appliedTo(WatchStatus status) {
    if (!onlyFavorites || status == WatchStatus.completed) return this;
    return LibraryFilter(query: query);
  }

  @override
  bool operator ==(Object other) =>
      other is LibraryFilter &&
      other.query == query &&
      other.onlyFavorites == onlyFavorites;

  @override
  int get hashCode => Object.hash(query, onlyFavorites);
}

/// Holds the library query and favorites filter for the session; never
/// persisted, so the library opens unfiltered.
class LibraryFilterNotifier extends Notifier<LibraryFilter> {
  @override
  LibraryFilter build() => const LibraryFilter();

  void setQuery(String query) {
    state = LibraryFilter(query: query, onlyFavorites: state.onlyFavorites);
  }

  void clearQuery() => setQuery('');

  void toggleOnlyFavorites() {
    state = LibraryFilter(
      query: state.query,
      onlyFavorites: !state.onlyFavorites,
    );
  }
}

final NotifierProvider<LibraryFilterNotifier, LibraryFilter>
libraryFilterProvider = NotifierProvider<LibraryFilterNotifier, LibraryFilter>(
  LibraryFilterNotifier.new,
);

/// Items of one library tab: filtered, grouped by franchise and sorted.
///
/// Filtering runs before grouping so that a group with one matching member
/// does not drag its other members along. Sorting runs after grouping
/// because alphabetical order uses the group label. While the relation graph
/// is loading or unavailable, entries are shown ungrouped.
final ProviderFamily<List<LibraryItem>, WatchStatus> libraryGroupsProvider =
    Provider.family<List<LibraryItem>, WatchStatus>((
      Ref ref,
      WatchStatus status,
    ) {
      final List<Entry> entries =
          ref.watch(visibleLibraryEntriesProvider).value ?? const <Entry>[];
      final List<Entry> ofStatus = entries
          .where((Entry e) => e.status == status)
          .toList(growable: false);
      final LibraryFilter filter = ref
          .watch(libraryFilterProvider)
          .appliedTo(status);
      final List<Entry> filtered = ref.watch(filterLibraryProvider)(
        ofStatus,
        query: filter.query,
        onlyFavorites: filter.onlyFavorites,
      );
      final Map<int, AnimeRelationNode> relations =
          ref.watch(libraryRelationsProvider).value ??
          const <int, AnimeRelationNode>{};
      final List<LibraryItem> grouped = ref.watch(groupLibraryProvider)(
        filtered,
        relations,
      );
      final LibrarySort sort = ref.watch(libraryOrderProvider);
      return ref.watch(sortLibraryProvider)(
        grouped,
        sort.order,
        reversed: sort.reversed,
      );
    });

/// Keys of the expanded groups. Kept for the session only, so every group
/// starts collapsed after a restart.
class ExpandedGroups extends Notifier<Set<int>> {
  @override
  Set<int> build() => const <int>{};

  void toggle(int key) {
    final Set<int> next = Set<int>.of(state);
    if (!next.remove(key)) next.add(key);
    state = next;
  }
}

final NotifierProvider<ExpandedGroups, Set<int>> expandedGroupsProvider =
    NotifierProvider<ExpandedGroups, Set<int>>(ExpandedGroups.new);
