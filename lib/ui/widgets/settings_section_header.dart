import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Title over a group of settings, in the accent color.
class SettingsSectionHeader extends StatelessWidget {
  const SettingsSectionHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        AppSpacing.s24,
        AppSpacing.s16,
        AppSpacing.s8,
      ),
      child: Semantics(
        header: true,
        child: Text(
          title,
          style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(color: context.palette.accent),
        ),
      ),
    );
  }
}
