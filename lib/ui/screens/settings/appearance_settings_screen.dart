import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../shell/content_column.dart';
import '../../state/settings_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/settings_section_header.dart';

const double _swatchSize = 44;
const double _swatchRing = 2;

class AppearanceSettingsScreen extends ConsumerWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final bool dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsAppearance)),
      body: SafeArea(
        top: false,
        child: ContentColumn(
          maxWidth: AppLayout.readableMaxWidth,
          child: ListView(
            children: <Widget>[
              SettingsSectionHeader(l10n.appearanceTheme),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s16,
                  vertical: AppSpacing.s8,
                ),
                child: SegmentedButton<ThemeMode>(
                  expandedInsets: EdgeInsets.zero,
                  segments: <ButtonSegment<ThemeMode>>[
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.system,
                      label: Text(l10n.appearanceSystem),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.light,
                      label: Text(l10n.appearanceLight),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.dark,
                      label: Text(l10n.appearanceDark),
                    ),
                  ],
                  selected: <ThemeMode>{ref.watch(themeModeProvider)},
                  onSelectionChanged: (Set<ThemeMode> selection) => ref
                      .read(themeModeProvider.notifier)
                      .set(selection.single),
                ),
              ),
              SwitchListTile(
                title: Text(l10n.appearancePureBlack),
                subtitle: Text(l10n.appearancePureBlackSubtitle),
                value: ref.watch(pureBlackProvider),
                onChanged: dark
                    ? ref.read(pureBlackProvider.notifier).set
                    : null,
              ),
              ListTile(title: Text(l10n.appearanceAccent)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
                child: Wrap(
                  spacing: AppSpacing.s4,
                  runSpacing: AppSpacing.s4,
                  children: <Widget>[
                    for (final AppAccent accent in AppAccent.values)
                      _AccentSwatch(
                        color: dark ? accent.dark : accent.light,
                        label: _accentName(l10n, accent),
                        selected: ref.watch(accentProvider) == accent,
                        onTap: () =>
                            ref.read(accentProvider.notifier).set(accent),
                      ),
                  ],
                ),
              ),
              SettingsSectionHeader(l10n.appearanceDisplay),
              ListTile(
                title: Text(l10n.appearanceLanguage),
                subtitle: Text(
                  _languageName(l10n, ref.watch(appLanguageProvider)),
                ),
                onTap: () => unawaited(_pickLanguage(context, ref)),
              ),
              ListTile(
                title: Text(l10n.appearanceFirstWeekday),
                subtitle: Text(
                  _firstWeekdayName(
                    l10n,
                    ref.watch(firstWeekdayPreferenceProvider),
                    ref.watch(regionFirstWeekdayProvider),
                  ),
                ),
                onTap: () => unawaited(_pickFirstWeekday(context, ref)),
              ),
              const SizedBox(height: AppSpacing.s24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickLanguage(BuildContext context, WidgetRef ref) async {
    final AppLanguage? picked = await _pickOption<AppLanguage>(
      context,
      title: context.l10n.appearanceLanguage,
      values: AppLanguage.values,
      current: ref.read(appLanguageProvider),
      name: (AppLanguage language) => _languageName(context.l10n, language),
    );
    if (picked != null) ref.read(appLanguageProvider.notifier).set(picked);
  }

  Future<void> _pickFirstWeekday(BuildContext context, WidgetRef ref) async {
    final int regionWeekday = ref.read(regionFirstWeekdayProvider);
    final FirstWeekday? picked = await _pickOption<FirstWeekday>(
      context,
      title: context.l10n.appearanceFirstWeekday,
      values: FirstWeekday.values,
      current: ref.read(firstWeekdayPreferenceProvider),
      name: (FirstWeekday day) =>
          _firstWeekdayName(context.l10n, day, regionWeekday),
    );
    if (picked != null) {
      ref.read(firstWeekdayPreferenceProvider.notifier).set(picked);
    }
  }

  /// Asks for one of [values] in a dialog, with [current] checked; returns
  /// null when cancelled.
  Future<T?> _pickOption<T>(
    BuildContext context, {
    required String title,
    required List<T> values,
    required T current,
    required String Function(T value) name,
  }) {
    return showDialog<T>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(title),
        contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
        content: RadioGroup<T>(
          groupValue: current,
          onChanged: (T? value) => Navigator.pop(context, value),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final T value in values)
                RadioListTile<T>(value: value, title: Text(name(value))),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.commonCancel),
          ),
        ],
      ),
    );
  }
}

/// [regionWeekday] is the first day of the device's region, named in the
/// region option so the user knows what it amounts to.
String _firstWeekdayName(
  AppLocalizations l10n,
  FirstWeekday day,
  int regionWeekday,
) {
  return switch (day) {
    FirstWeekday.region => l10n.appearanceFirstWeekdayRegion(
      regionWeekday == DateTime.sunday ? 'sunday' : 'monday',
    ),
    FirstWeekday.monday => l10n.appearanceMonday,
    FirstWeekday.sunday => l10n.appearanceSunday,
  };
}

/// Languages are named in their own language, so a user who cannot read the
/// current one still finds theirs; only the system option is translated.
String _languageName(AppLocalizations l10n, AppLanguage language) {
  return switch (language) {
    AppLanguage.system => l10n.appearanceSystem,
    AppLanguage.es => 'Español',
    AppLanguage.en => 'English',
  };
}

String _accentName(AppLocalizations l10n, AppAccent accent) {
  return switch (accent) {
    AppAccent.indigo => l10n.appearanceAccentIndigo,
    AppAccent.teal => l10n.appearanceAccentTeal,
    AppAccent.green => l10n.appearanceAccentGreen,
    AppAccent.amber => l10n.appearanceAccentAmber,
    AppAccent.orange => l10n.appearanceAccentOrange,
    AppAccent.pink => l10n.appearanceAccentPink,
  };
}

/// A circle of an accent color, ringed and checked when [selected].
class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: _swatchSize / 2 + AppSpacing.s4,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s2),
          child: AnimatedContainer(
            duration: AppDuration.fast,
            curve: AppDuration.curve,
            width: _swatchSize,
            height: _swatchSize,
            padding: const EdgeInsets.all(_swatchRing * 2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? color : Colors.transparent,
                width: _swatchRing,
              ),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: selected
                  ? Icon(
                      Icons.check,
                      size: AppSizes.iconMd,
                      color: AppPalette.onAccentFor(color),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
