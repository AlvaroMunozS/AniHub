import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../domain/values/watch_status.dart';
import '../../l10n/l10n.dart';
import '../theme/app_theme.dart';
import '../theme/status_style.dart';

/// Display order of the statuses, which differs from the declaration order
/// of [WatchStatus].
const List<WatchStatus> _order = <WatchStatus>[
  WatchStatus.planned,
  WatchStatus.watching,
  WatchStatus.completed,
];

/// Fits a [StatusActionButton]: an [AppSizes.iconLg] icon above a
/// `labelMedium` label.
const double _height = 64;

/// Animation value below which, while closing, the other statuses are fully
/// transparent. See [_StatusSelectorState._sideOpacity].
const double _closeFadeThreshold = 0.6;

/// Expanding status picker.
///
/// Collapsed, it shows the current status, or an add button for an anime
/// outside the library. Tapping it expands every status in place; choosing
/// one collapses it and reports the choice through [onSelected]. It always
/// shows [current], so a choice that is ignored or fails never lingers.
class StatusSelector extends StatefulWidget {
  const StatusSelector({
    required this.current,
    required this.onSelected,
    required this.collapsedWidth,
    required this.expandedWidth,
    this.enabled = true,
    super.key,
  });

  /// Null when the anime is not in the library.
  final WatchStatus? current;

  final ValueChanged<WatchStatus> onSelected;
  final double collapsedWidth;
  final double expandedWidth;
  final bool enabled;

  @override
  State<StatusSelector> createState() => _StatusSelectorState();
}

class _StatusSelectorState extends State<StatusSelector>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _t;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: AppDuration.slow);
    _t = CurvedAnimation(
      parent: _controller,
      curve: AppDuration.curve,
      reverseCurve: AppDuration.curve.flipped,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _expand() {
    if (!widget.enabled || _open) return;
    setState(() => _open = true);
    unawaited(_controller.forward());
  }

  void _collapse() {
    if (!_open) return;
    setState(() => _open = false);
    unawaited(_controller.reverse());
  }

  void _handleCurrentTap() {
    if (_open) {
      _collapse();
    } else {
      _expand();
    }
  }

  void _handleSelect(WatchStatus status) {
    widget.onSelected(status);
    _collapse();
  }

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      onTapOutside: (PointerDownEvent _) => _collapse(),
      child: AnimatedBuilder(
        animation: _t,
        builder: (BuildContext context, Widget? _) {
          final double t = _t.value;
          final double width = lerpDouble(
            widget.collapsedWidth,
            widget.expandedWidth,
            t,
          )!;
          final double anchor = widget.collapsedWidth / 2;
          final double slot = widget.expandedWidth / _order.length;

          return SizedBox(
            height: _height,
            width: width,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                if (widget.current == null) _buildAdd(t),
                for (int i = 0; i < _order.length; i++)
                  _buildItem(_order[i], i, t, anchor, slot),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAdd(double t) {
    return Positioned(
      left: 0,
      top: 0,
      bottom: 0,
      width: widget.collapsedWidth,
      child: IgnorePointer(
        ignoring: !widget.enabled || t > 0,
        child: Opacity(
          opacity: 1 - t,
          child: StatusActionButton(
            icon: Icons.add_circle_outline,
            label: context.l10n.statusSelectorAdd,
            color: context.palette.textSecondary,
            onTap: _expand,
          ),
        ),
      ),
    );
  }

  /// Opacity of a status other than the current one.
  ///
  /// Follows `t` while opening. While closing, the other statuses converge
  /// onto the current one and would be visible overlapping it, so they are
  /// fully hidden once `t` drops below [_closeFadeThreshold].
  double _sideOpacity(double t) {
    final bool closing = _controller.status == AnimationStatus.reverse;
    if (!closing) return t;
    return (t / _closeFadeThreshold).clamp(0.0, 1.0);
  }

  Widget _buildItem(
    WatchStatus status,
    int index,
    double t,
    double anchor,
    double slot,
  ) {
    final bool isCurrent = status == widget.current;
    final double center = slot * (index + 0.5);
    final double x = lerpDouble(anchor, center, t)!;
    final double opacity = isCurrent ? 1.0 : _sideOpacity(t);
    final bool interactive = widget.enabled && (isCurrent || t == 1.0);

    return Positioned(
      left: x - slot / 2,
      top: 0,
      bottom: 0,
      width: slot,
      child: IgnorePointer(
        ignoring: !interactive,
        // Plain `Opacity`: the value is already animated every frame, and an
        // `AnimatedOpacity` would lag behind it and defeat the early fade-out
        // of `_sideOpacity`.
        child: Opacity(
          opacity: opacity,
          child: Semantics(
            selected: isCurrent,
            button: true,
            expanded: isCurrent ? _open : null,
            onTapHint: isCurrent ? context.l10n.statusSelectorChange : null,
            child: StatusActionButton(
              icon: statusIcon(status, selected: isCurrent),
              label: statusLabel(context.l10n, status),
              color: isCurrent
                  ? statusColor(context.palette, status)
                  : context.palette.textSecondary,
              onTap: isCurrent
                  ? _handleCurrentTap
                  : () => _handleSelect(status),
            ),
          ),
        ),
      ),
    );
  }
}

/// Large icon above a label, with no background or border. Shared by
/// [StatusSelector] and the favorite button next to it.
class StatusActionButton extends StatelessWidget {
  const StatusActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.tooltip,
    super.key,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final Widget content = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: AppSizes.iconLg, color: color),
          const SizedBox(height: AppSpacing.s4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
    final Widget button = InkWell(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: onTap,
      child: content,
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
