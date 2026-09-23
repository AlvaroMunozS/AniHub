import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/usecases/usecases.dart';
import '../../domain/entities/entry.dart';
import '../../domain/values/watch_status.dart';
import '../../l10n/l10n.dart';
import '../router.dart';
import '../shell/content_column.dart';
import '../state/library_providers.dart';
import '../theme/app_theme.dart';
import '../theme/status_style.dart';
import '../widgets/empty_state.dart';
import '../widgets/library/animated_poster_grid.dart';
import '../widgets/library/library_options_sheet.dart';
import '../widgets/pill_search_bar.dart';
import '../widgets/poster_grid.dart';

/// Shows the library as one swipeable tab per [WatchStatus], each a poster
/// grid where franchises collapse into expandable groups.
///
/// The [TabController] and the route stay in sync both ways: settling on a
/// tab navigates to its route, and arriving at a route moves the tab.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({required this.status, super.key});

  /// The tab to show.
  final WatchStatus status;

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: WatchStatus.values.length,
      vsync: this,
      initialIndex: widget.status.index,
    )..addListener(_onTabSettled);
    _searchController = TextEditingController(
      text: ref.read(libraryFilterProvider).query,
    );
  }

  @override
  void didUpdateWidget(LibraryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_tabController.index != widget.status.index) {
      _tabController.animateTo(widget.status.index);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Navigates once a tab settles; `indexIsChanging` stays true for the whole
  /// tab animation.
  void _onTabSettled() {
    if (_tabController.indexIsChanging) return;
    final WatchStatus target = WatchStatus.values[_tabController.index];
    if (target != widget.status) context.go(RoutePaths.libraryFor(target));
  }

  @override
  Widget build(BuildContext context) {
    // Mirrors filter changes made elsewhere, e.g. `AppShell` clearing the
    // query when leaving the library.
    ref.listen<LibraryFilter>(libraryFilterProvider, (
      LibraryFilter? previous,
      LibraryFilter next,
    ) {
      if (next.query != _searchController.text) {
        _searchController.text = next.query;
      }
    });
    final bool onlyFavorites = ref.watch(
      libraryFilterProvider.select(
        (LibraryFilter f) => f.appliedTo(widget.status).onlyFavorites,
      ),
    );
    final AsyncValue<List<Entry>> entries = ref.watch(
      visibleLibraryEntriesProvider,
    );

    return SafeArea(
      bottom: false,
      child: Column(
        children: <Widget>[
          // Both already inset their content by the gutter, which lines it
          // up with the grid below.
          ContentColumn(
            padded: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                PillSearchBar(
                  controller: _searchController,
                  hintText: context.l10n.librarySearchHint,
                  onChanged: (String value) =>
                      ref.read(libraryFilterProvider.notifier).setQuery(value),
                  onClear: () =>
                      ref.read(libraryFilterProvider.notifier).clearQuery(),
                  onFilter: () => showLibraryOptionsSheet(
                    context,
                    withFavoritesFilter: widget.status == WatchStatus.completed,
                  ),
                  filterActive: onlyFavorites,
                ),
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: <Widget>[
                    for (final WatchStatus status in WatchStatus.values)
                      Tab(text: statusLabel(context.l10n, status)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          if (entries.hasError && entries.hasValue) const _StaleLibraryNotice(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: <Widget>[
                for (final WatchStatus status in WatchStatus.values)
                  ContentColumn(
                    alignment: Alignment.topCenter,
                    child: _LibraryTab(status: status),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryTab extends ConsumerWidget {
  const _LibraryTab({required this.status});

  final WatchStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Entry>> entries = ref.watch(
      visibleLibraryEntriesProvider,
    );
    return entries.when(
      skipError: true,
      loading: () => const PosterGridSkeleton(),
      error: (Object error, StackTrace stackTrace) => EmptyState(
        icon: Icons.error_outline,
        title: context.l10n.libraryLoadFailed,
        message: context.l10n.catalogRetryLater,
        actionLabel: context.l10n.commonRetry,
        onAction: () => ref.invalidate(libraryEntriesProvider),
      ),
      data: (List<Entry> list) {
        if (!list.any((Entry e) => e.status == status)) {
          if (list.isEmpty && status == WatchStatus.watching) {
            return EmptyState(
              icon: Icons.inbox_outlined,
              title: context.l10n.libraryEmptyTitle,
              message: context.l10n.libraryEmptyMessage,
            );
          }
          return _EmptyTab(status: status);
        }
        final List<LibraryItem> items = ref.watch(
          libraryGroupsProvider(status),
        );
        if (items.isEmpty) {
          return _FilteredEmptyState(
            status: status,
            filter: ref.watch(libraryFilterProvider).appliedTo(status),
          );
        }
        return AnimatedPosterGrid(
          items: items,
          expanded: ref.watch(expandedGroupsProvider),
          onOpen: (Entry e) => context.push(RoutePaths.animeDetail(e.malId)),
          onToggle: (int key) =>
              ref.read(expandedGroupsProvider.notifier).toggle(key),
        );
      },
    );
  }
}

/// Shown when the library stream fails after emitting data, so the last
/// known list stays visible instead of being replaced by an error.
class _StaleLibraryNotice extends StatelessWidget {
  const _StaleLibraryNotice();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s12),
      child: Text(
        context.l10n.libraryStale,
        style: AppTypography.caption.copyWith(color: context.palette.textFaint),
      ),
    );
  }
}

class _EmptyTab extends StatelessWidget {
  const _EmptyTab({required this.status});

  final WatchStatus status;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return EmptyState(
      icon: statusIcon(status, selected: false),
      title: switch (status) {
        WatchStatus.watching => l10n.libraryEmptyWatchingTitle,
        WatchStatus.planned => l10n.libraryEmptyPlannedTitle,
        WatchStatus.completed => l10n.libraryEmptyCompletedTitle,
      },
      message: switch (status) {
        WatchStatus.watching => l10n.libraryEmptyWatchingMessage,
        WatchStatus.planned => l10n.libraryEmptyPlannedMessage,
        WatchStatus.completed => l10n.libraryEmptyCompletedMessage,
      },
    );
  }
}

/// Shown when the tab has entries but none match the active filter.
class _FilteredEmptyState extends StatelessWidget {
  const _FilteredEmptyState({required this.status, required this.filter});

  final WatchStatus status;
  final LibraryFilter filter;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String query = filter.query.trim();
    final String label = statusLabel(l10n, status);
    final String message;
    if (query.isNotEmpty && filter.onlyFavorites) {
      message = l10n.libraryNoFavoritesMatching(query, label);
    } else if (query.isNotEmpty) {
      message = l10n.libraryNothingMatching(query, label);
    } else {
      message = l10n.libraryNoFavorites(label);
    }
    return EmptyState(
      icon: Icons.search_off,
      title: l10n.commonNoResults,
      message: message,
    );
  }
}
