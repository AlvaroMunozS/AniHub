import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../theme/app_theme.dart';

/// Larger than body text, since the search bar leads its screen.
const double _fontSize = 17;

/// Height of the pill, which also serves as the screen's top bar.
const double _height = 52;

/// Fits the clear button or the bookmark, so the field keeps its width with
/// either or neither.
const double _slotWidth = kMinInteractiveDimension;

/// Rounded search field that serves as the top bar of its screen, with a
/// clear button, an optional bookmark that shows only the user's series, and
/// an optional filter button.
class PillSearchBar extends StatefulWidget {
  const PillSearchBar({
    required this.controller,
    required this.hintText,
    required this.onChanged,
    required this.onClear,
    this.onFilter,
    this.filterActive = false,
    this.onToggleMine,
    this.mineActive = false,
    super.key,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;

  /// Called by the clear button, which shows only while the field has text.
  final VoidCallback onClear;

  final VoidCallback? onFilter;
  final bool filterActive;

  /// Called with the new state when the bookmark is tapped; null hides it.
  /// It shares the clear button's slot, so it shows only while the field is
  /// empty.
  final ValueChanged<bool>? onToggleMine;
  final bool mineActive;

  @override
  State<PillSearchBar> createState() => _PillSearchBarState();
}

/// Listens to the controller so the clear button reacts to every keystroke,
/// even when the parent only rebuilds after a debounce.
class _PillSearchBarState extends State<PillSearchBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(PillSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() => setState(() {});

  Widget? _mineButton(BuildContext context) {
    final ValueChanged<bool>? onToggle = widget.onToggleMine;
    if (onToggle == null) return null;
    final bool active = widget.mineActive;
    return IconButton(
      tooltip: context.l10n.searchAiringMine,
      isSelected: active,
      icon: Icon(Icons.bookmark_border, color: context.palette.textSecondary),
      selectedIcon: Icon(Icons.bookmark, color: context.palette.accent),
      style: IconButton.styleFrom(
        backgroundColor: active ? context.palette.accentSoft : null,
      ),
      onPressed: () => onToggle(!active),
      visualDensity: VisualDensity.compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasText = widget.controller.text.isNotEmpty;
    final TextStyle textStyle = Theme.of(context).textTheme.bodyMedium!
        .copyWith(fontSize: _fontSize);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s8,
      ),
      child: Material(
        color: context.palette.surfaceHigh,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: SizedBox(
          height: _height,
          child: Row(
            children: <Widget>[
              const SizedBox(width: AppSpacing.s16),
              Icon(
                Icons.search,
                color: context.palette.textFaint,
                size: AppSizes.iconLg,
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  onChanged: widget.onChanged,
                  style: textStyle,
                  decoration: InputDecoration.collapsed(
                    hintText: widget.hintText,
                    hintStyle: textStyle.copyWith(
                      color: context.palette.textFaint,
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: _slotWidth,
                child: hasText
                    ? IconButton(
                        tooltip: context.l10n.searchBarClear,
                        icon: const Icon(Icons.close, size: AppSizes.iconMd),
                        onPressed: widget.onClear,
                        visualDensity: VisualDensity.compact,
                      )
                    : _mineButton(context),
              ),
              if (widget.onFilter != null)
                IconButton(
                  tooltip: widget.filterActive
                      ? context.l10n.searchBarFilterActive
                      : context.l10n.searchBarFilter,
                  icon: Icon(
                    Icons.filter_list,
                    color: widget.filterActive
                        ? context.palette.accent
                        : context.palette.textSecondary,
                  ),
                  onPressed: widget.onFilter,
                  visualDensity: VisualDensity.compact,
                ),
              const SizedBox(width: AppSpacing.s4),
            ],
          ),
        ),
      ),
    );
  }
}
