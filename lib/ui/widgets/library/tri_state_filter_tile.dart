import 'package:flutter/material.dart';

import '../../../application/usecases/filter_mode.dart';
import '../../../l10n/l10n.dart';
import '../../theme/app_theme.dart';

/// A filter that cycles through [FilterMode.any], [FilterMode.only] and
/// [FilterMode.exclude] on each tap.
class TriStateFilterTile extends StatelessWidget {
  const TriStateFilterTile({
    super.key,
    required this.label,
    required this.mode,
    required this.onTap,
  });

  final String label;
  final FilterMode mode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool active = mode != FilterMode.any;
    // The icon alone does not tell a screen reader what the filter does, so
    // the tile announces the mode as its value.
    return Semantics(
      label: label,
      value: switch (mode) {
        FilterMode.any => context.l10n.libraryFilterAny,
        FilterMode.only => context.l10n.libraryFilterOnly,
        FilterMode.exclude => context.l10n.libraryFilterExcluded,
      },
      button: true,
      onTap: onTap,
      excludeSemantics: true,
      child: ListTile(
        leading: Icon(
          switch (mode) {
            FilterMode.any => Icons.check_box_outline_blank,
            FilterMode.only => Icons.check_box,
            FilterMode.exclude => Icons.disabled_by_default,
          },
          color: active ? context.palette.accent : null,
          size: AppSizes.iconMd,
        ),
        title: Text(label),
        onTap: onTap,
      ),
    );
  }
}
