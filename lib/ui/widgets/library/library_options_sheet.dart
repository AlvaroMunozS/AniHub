import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/usecases/library_order.dart';
import '../../../domain/values/watch_status.dart';
import '../../../l10n/l10n.dart';
import '../../state/library_providers.dart';
import '../../theme/app_theme.dart';
import 'tri_state_filter_tile.dart';

/// Shows the library sort options, and the filters that apply to the
/// [status] tab: favorites in completed, not started in planned.
///
/// Uses the root navigator so the sheet also covers the bottom navigation
/// bar.
Future<void> showLibraryOptionsSheet(
  BuildContext context, {
  required WatchStatus status,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (BuildContext context) => _LibraryOptionsSheet(status: status),
  );
}

/// Fraction of the screen height the sheet takes.
const double _heightFactor = 0.6;

class _LibraryOptionsSheet extends StatelessWidget {
  const _LibraryOptionsSheet({required this.status});

  final WatchStatus status;

  @override
  Widget build(BuildContext context) {
    final List<(String, Widget)> tabs = <(String, Widget)>[
      if (status != WatchStatus.watching)
        (context.l10n.libraryOptionsFilter, _FilterTab(status: status)),
      (context.l10n.libraryOptionsSort, const _SortTab()),
    ];
    return SafeArea(
      child: DefaultTabController(
        length: tabs.length,
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * _heightFactor,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TabBar(
                tabs: <Widget>[
                  for (final (String label, Widget _) in tabs) Tab(text: label),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: <Widget>[
                    for (final (String _, Widget tab) in tabs) tab,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterTab extends ConsumerWidget {
  const _FilterTab({required this.status});

  final WatchStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final LibraryFilter filter = ref.watch(libraryFilterProvider);
    final LibraryFilterNotifier notifier = ref.read(
      libraryFilterProvider.notifier,
    );
    return ListView(
      children: <Widget>[
        if (status == WatchStatus.completed)
          TriStateFilterTile(
            label: context.l10n.libraryOptionsFavorites,
            mode: filter.favorites,
            onTap: notifier.cycleFavorites,
          ),
        if (status == WatchStatus.planned)
          TriStateFilterTile(
            label: context.l10n.libraryOptionsNotStarted,
            mode: filter.notStarted,
            onTap: notifier.cycleNotStarted,
          ),
      ],
    );
  }
}

class _SortTab extends ConsumerWidget {
  const _SortTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final LibrarySort sort = ref.watch(libraryOrderProvider);
    return ListView(
      children: <Widget>[
        _SortOption(
          label: context.l10n.libraryOptionsSortByTitle,
          order: LibraryOrder.alphabetical,
          sort: sort,
        ),
        _SortOption(
          label: context.l10n.libraryOptionsSortByRecent,
          order: LibraryOrder.recent,
          sort: sort,
        ),
      ],
    );
  }
}

class _SortOption extends ConsumerWidget {
  const _SortOption({
    required this.label,
    required this.order,
    required this.sort,
  });

  final String label;
  final LibraryOrder order;
  final LibrarySort sort;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool active = sort.order == order;
    return ListTile(
      selected: active,
      leading: SizedBox(
        width: AppSizes.iconMd,
        child: active
            ? Icon(
                sort.reversed ? Icons.arrow_downward : Icons.arrow_upward,
                color: context.palette.accent,
                size: AppSizes.iconMd,
                semanticLabel: sort.reversed
                    ? context.l10n.libraryOptionsDescending
                    : context.l10n.libraryOptionsAscending,
              )
            : null,
      ),
      title: Text(
        label,
        style: active
            ? Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: context.palette.accent)
            : null,
      ),
      onTap: () => ref.read(libraryOrderProvider.notifier).select(order),
    );
  }
}
