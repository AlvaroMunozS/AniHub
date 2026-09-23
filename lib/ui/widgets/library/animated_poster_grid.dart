import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../application/usecases/usecases.dart';
import '../../../domain/entities/entry.dart';
import '../../theme/app_theme.dart';
import '../entry_card.dart';
import '../group_card.dart';
import '../poster_card.dart';
import '../poster_grid_metrics.dart';
import 'group_member.dart';

/// Indent of the rail that marks the members of an expanded group.
const double _memberIndent = AppSpacing.s4;

/// Rows built beyond each edge of the viewport, so scrolling never reveals
/// unbuilt cells.
const int _extraRows = 2;

/// A visible grid cell. An expanded group contributes its own cell plus one
/// cell per member.
sealed class _Cell {
  const _Cell();

  /// Key of the group this cell belongs to, or null for a standalone entry.
  int? get blockKey;
}

class _GroupCell extends _Cell {
  const _GroupCell(this.group);

  final LibraryGroupItem group;

  @override
  int? get blockKey => group.key;
}

class _EntryCell extends _Cell {
  const _EntryCell(this.entry, {this.blockKey});

  final Entry entry;

  @override
  final int? blockKey;
}

List<_Cell> _flatten(List<LibraryItem> items, Set<int> expanded) {
  final List<_Cell> cells = <_Cell>[];
  for (final LibraryItem item in items) {
    switch (item) {
      case final LibraryEntryItem entryItem:
        cells.add(_EntryCell(entryItem.entry));
      case final LibraryGroupItem groupItem:
        cells.add(_GroupCell(groupItem));
        if (expanded.contains(groupItem.key)) {
          for (final Entry member in groupItem.members) {
            cells.add(_EntryCell(member, blockKey: groupItem.key));
          }
        }
    }
  }
  return cells;
}

String _cellKey(_Cell cell) => switch (cell) {
  _GroupCell(:final group) => 'group-${group.key}',
  _EntryCell(:final entry) => 'entry-${entry.malId}',
};

/// Library poster grid that animates layout changes.
///
/// Cells have a uniform size and are placed by hand with
/// [AnimatedPositioned], so expanding or collapsing a group slides the
/// following cells into place; `GridView` does not animate relayouts. Only
/// rows near the viewport are built.
///
/// Collapsing reports [onToggle] only after the members fade out, so they do
/// not vanish while the other cells start to move.
class AnimatedPosterGrid extends StatefulWidget {
  const AnimatedPosterGrid({
    required this.items,
    required this.expanded,
    required this.onOpen,
    required this.onToggle,
    super.key,
  });

  final List<LibraryItem> items;
  final Set<int> expanded;
  final void Function(Entry) onOpen;
  final void Function(int groupKey) onToggle;

  @override
  State<AnimatedPosterGrid> createState() => _AnimatedPosterGridState();
}

class _AnimatedPosterGridState extends State<AnimatedPosterGrid> {
  /// Groups being collapsed whose members are still fading out, with the
  /// timer that reports the collapse.
  final Map<int, Timer> _collapsing = <int, Timer>{};

  final ScrollController _scrollController = ScrollController();

  /// Geometry from the last build, so the scroll listener can recompute the
  /// visible range without waiting for a rebuild.
  GridMetrics? _metrics;

  /// Row range built by the last build; scrolling rebuilds the grid only
  /// when it changes.
  int _firstRow = -1;
  int _lastRow = -1;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    for (final Timer timer in _collapsing.values) {
      timer.cancel();
    }
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    final GridMetrics? metrics = _metrics;
    if (metrics == null || !_scrollController.hasClients) return;
    final (int first, int last) = _visibleRows(
      metrics,
      _scrollController.offset,
      _scrollController.position.viewportDimension,
    );
    if (first != _firstRow || last != _lastRow) {
      setState(() {
        _firstRow = first;
        _lastRow = last;
      });
    }
  }

  (int, int) _visibleRows(GridMetrics metrics, double offset, double viewport) {
    final double rowExtent = metrics.cellHeight + GridMetrics.mainAxisSpacing;
    final int first = math.max(0, (offset / rowExtent).floor() - _extraRows);
    final int last = ((offset + viewport) / rowExtent).ceil() + _extraRows;
    return (first, last);
  }

  /// Expands at once, since new member cells animate in by themselves.
  /// Collapsing waits [AppDuration.base] for the members to fade out before
  /// reporting the toggle.
  void _handleToggle(int key) {
    final Timer? pending = _collapsing.remove(key);
    if (pending != null) {
      // Tapped again while fading out: cancel the pending collapse.
      pending.cancel();
      setState(() {});
      return;
    }
    if (!widget.expanded.contains(key)) {
      widget.onToggle(key);
      return;
    }
    setState(() {
      _collapsing[key] = Timer(AppDuration.base, () {
        setState(() => _collapsing.remove(key));
        widget.onToggle(key);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<_Cell> cells = _flatten(widget.items, widget.expanded);
    final TextStyle titleStyle = PosterCard.titleStyleOf(context);
    final TextScaler textScaler = MediaQuery.textScalerOf(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final GridMetrics metrics = GridMetrics.of(
          constraints.maxWidth,
          cells.length,
          titleStyle,
          textScaler,
        );
        _metrics = metrics;
        final double offset = _scrollController.hasClients
            ? _scrollController.offset
            : 0;
        final double viewport = _scrollController.hasClients
            ? _scrollController.position.viewportDimension
            : constraints.maxHeight;
        final (int first, int last) = _visibleRows(metrics, offset, viewport);
        _firstRow = first;
        _lastRow = last;

        return SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.only(bottom: AppSpacing.s24),
          child: SizedBox(
            height: metrics.totalHeight,
            child: Stack(
              children: <Widget>[
                for (int i = 0; i < cells.length; i++)
                  if (_rowOf(i, metrics) >= first && _rowOf(i, metrics) <= last)
                    _positioned(cells[i], i, metrics),
              ],
            ),
          ),
        );
      },
    );
  }

  int _rowOf(int index, GridMetrics metrics) => index ~/ metrics.crossAxisCount;

  Widget _positioned(_Cell cell, int index, GridMetrics metrics) {
    final Offset origin = metrics.offsetFor(index);
    final Widget card = switch (cell) {
      _GroupCell(:final group) => GroupCard(
        label: group.label,
        coverUrls: group.members
            .map((Entry e) => e.coverUrl)
            .toList(growable: false),
        expanded: widget.expanded.contains(group.key),
        onTap: () => _handleToggle(group.key),
      ),
      _EntryCell(:final entry) => EntryCard(
        entry: entry,
        onOpen: () => widget.onOpen(entry),
      ),
    };
    return AnimatedPositioned(
      key: ValueKey<String>(_cellKey(cell)),
      duration: AppDuration.base,
      curve: AppDuration.curve,
      left: origin.dx,
      top: origin.dy,
      width: metrics.cellWidth,
      height: metrics.cellHeight,
      child: _wrap(cell, card),
    );
  }

  Widget _wrap(_Cell cell, Widget child) {
    if (cell is! _EntryCell || cell.blockKey == null) return child;
    return GroupMemberTransition(
      visible: !_collapsing.containsKey(cell.blockKey),
      child: GroupMemberSlot(indent: _memberIndent, child: child),
    );
  }
}
