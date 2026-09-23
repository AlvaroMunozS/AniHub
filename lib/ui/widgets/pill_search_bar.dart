import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Larger than body text, since the search bar leads its screen.
const double _fontSize = 17;

/// Height of the pill, which also serves as the screen's top bar.
const double _height = 52;

/// Rounded search field that serves as the top bar of its screen, with a
/// clear button and an optional filter button.
class PillSearchBar extends StatefulWidget {
  const PillSearchBar({
    required this.controller,
    required this.hintText,
    required this.onChanged,
    required this.onClear,
    this.onFilter,
    this.filterActive = false,
    super.key,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;

  /// Called by the clear button, which shows only while the field has text.
  final VoidCallback onClear;

  final VoidCallback? onFilter;
  final bool filterActive;

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

  @override
  Widget build(BuildContext context) {
    final bool hasText = widget.controller.text.isNotEmpty;
    final TextStyle textStyle = AppTypography.textTheme.bodyMedium!.copyWith(
      fontSize: _fontSize,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s8,
      ),
      child: Material(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: SizedBox(
          height: _height,
          child: Row(
            children: <Widget>[
              const SizedBox(width: AppSpacing.s16),
              const Icon(
                Icons.search,
                color: AppColors.textFaint,
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
                    hintStyle: textStyle.copyWith(color: AppColors.textFaint),
                  ),
                ),
              ),
              if (hasText)
                IconButton(
                  tooltip: 'Limpiar',
                  icon: const Icon(Icons.close, size: AppSizes.iconMd),
                  onPressed: widget.onClear,
                  visualDensity: VisualDensity.compact,
                ),
              if (widget.onFilter != null)
                IconButton(
                  tooltip: widget.filterActive
                      ? 'Filtrar y ordenar (filtro activo)'
                      : 'Filtrar y ordenar',
                  icon: Icon(
                    Icons.filter_list,
                    color: widget.filterActive
                        ? AppColors.accent
                        : AppColors.textSecondary,
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
