import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/usecases/usecases.dart';
import '../../domain/entities/entry.dart';
import '../../domain/values/watch_status.dart';
import '../catalog_messages.dart';
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
          PillSearchBar(
            controller: _searchController,
            hintText: 'Buscar en la biblioteca',
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
                Tab(text: statusLabel(status)),
            ],
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
        title: 'No se pudo leer la biblioteca',
        message: retryLaterMessage,
        actionLabel: 'Reintentar',
        onAction: () => ref.invalidate(libraryEntriesProvider),
      ),
      data: (List<Entry> list) {
        if (!list.any((Entry e) => e.status == status)) {
          if (list.isEmpty && status == WatchStatus.watching) {
            return const EmptyState(
              icon: Icons.inbox_outlined,
              title: 'Tu biblioteca está vacía',
              message: 'Busca un anime para empezar a seguirlo.',
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
        'No se pudo actualizar la biblioteca; se muestra la última versión '
        'cargada.',
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
    return EmptyState(
      icon: statusIcon(status, selected: false),
      title: switch (status) {
        WatchStatus.watching => 'No estás viendo nada',
        WatchStatus.planned => 'No tienes nada pendiente',
        WatchStatus.completed => 'Aún no has completado nada',
      },
      message: switch (status) {
        WatchStatus.watching => 'Marca un anime como «Viendo» desde su ficha.',
        WatchStatus.planned =>
          'Guarda aquí los animes que quieras ver más adelante.',
        WatchStatus.completed => 'Los animes que termines aparecerán aquí.',
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
    final String query = filter.query.trim();
    final String label = statusLabel(status);
    final String message;
    if (query.isNotEmpty && filter.onlyFavorites) {
      message = 'No hay favoritos que coincidan con «$query» en $label.';
    } else if (query.isNotEmpty) {
      message = 'No hay nada para «$query» en $label.';
    } else {
      message = 'No tienes favoritos en $label.';
    }
    return EmptyState(
      icon: Icons.search_off,
      title: 'Sin resultados',
      message: message,
    );
  }
}
