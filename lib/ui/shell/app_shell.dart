import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/values/watch_status.dart';
import '../../l10n/l10n.dart';
import '../router.dart';
import '../state/library_providers.dart';

/// Bottom navigation destinations, in display order.
enum _Destination { library, search, more }

/// Hosts the shell routes above a bottom navigation bar, which is hidden on
/// detail screens.
///
/// Leaving the library clears its search query but keeps the favorites
/// filter for the rest of the session.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  /// The tab the library destination returns to.
  WatchStatus _lastLibraryTab = WatchStatus.watching;

  @override
  void initState() {
    super.initState();
    _trackLibraryTab();
  }

  @override
  void didUpdateWidget(AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    _trackLibraryTab();
  }

  void _trackLibraryTab() {
    final WatchStatus? tab = RoutePaths.libraryStatusOf(widget.location);
    if (tab != null) _lastLibraryTab = tab;
  }

  _Destination get _current {
    if (widget.location.startsWith(RoutePaths.search)) {
      return _Destination.search;
    }
    if (widget.location.startsWith(RoutePaths.more)) return _Destination.more;
    return _Destination.library;
  }

  void _go(BuildContext context, _Destination destination) {
    if (_current == _Destination.library &&
        destination != _Destination.library) {
      ref.read(libraryFilterProvider.notifier).clearQuery();
    }
    context.go(switch (destination) {
      _Destination.library => RoutePaths.libraryFor(_lastLibraryTab),
      _Destination.search => RoutePaths.search,
      _Destination.more => RoutePaths.more,
    });
  }

  @override
  Widget build(BuildContext context) {
    // The location cannot reveal a pushed detail route; see
    // `inAnimeDetailProvider`.
    final bool inDetail = ref.watch(inAnimeDetailProvider);
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: inDetail
          ? null
          : NavigationBar(
              selectedIndex: _current.index,
              onDestinationSelected: (int i) =>
                  _go(context, _Destination.values[i]),
              destinations: <NavigationDestination>[
                NavigationDestination(
                  icon: const Icon(Icons.collections_bookmark_outlined),
                  selectedIcon: const Icon(Icons.collections_bookmark),
                  label: context.l10n.navLibrary,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.explore_outlined),
                  selectedIcon: const Icon(Icons.explore),
                  label: context.l10n.navBrowse,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.more_horiz),
                  label: context.l10n.navMore,
                ),
              ],
            ),
    );
  }
}
