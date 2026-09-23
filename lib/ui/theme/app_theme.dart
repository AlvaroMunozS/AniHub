import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

// Re-exported so that widgets only need to import the theme.
export 'tokens.dart';
export 'typography.dart';

/// Sets every role explicitly, because roles left to `ColorScheme.dark` fall
/// back to Material's baseline teal and purple. Roles the app does not use
/// point to palette neutrals.
const ColorScheme _scheme = ColorScheme(
  brightness: Brightness.dark,
  primary: AppColors.accent,
  onPrimary: AppColors.onAccent,
  primaryContainer: AppColors.surfaceHigh,
  onPrimaryContainer: AppColors.accent,
  secondary: AppColors.textSecondary,
  onSecondary: AppColors.background,
  secondaryContainer: AppColors.surfaceHigh,
  onSecondaryContainer: AppColors.textPrimary,
  tertiary: AppColors.success,
  onTertiary: AppColors.background,
  tertiaryContainer: AppColors.surfaceHigh,
  onTertiaryContainer: AppColors.success,
  error: AppColors.danger,
  onError: AppColors.background,
  errorContainer: AppColors.dangerSoft,
  onErrorContainer: AppColors.danger,
  surface: AppColors.surface,
  onSurface: AppColors.textPrimary,
  onSurfaceVariant: AppColors.textSecondary,
  surfaceDim: AppColors.background,
  surfaceBright: AppColors.surfaceHigh,
  surfaceContainerLowest: AppColors.background,
  surfaceContainerLow: AppColors.surface,
  surfaceContainer: AppColors.surface,
  surfaceContainerHigh: AppColors.surfaceHigh,
  surfaceContainerHighest: AppColors.surfaceHigh,
  outline: AppColors.border,
  outlineVariant: AppColors.borderSubtle,
  shadow: Colors.black,
  scrim: AppColors.scrim,
  inverseSurface: AppColors.textPrimary,
  onInverseSurface: AppColors.background,
  inversePrimary: AppColors.accentPressed,
  surfaceTint: Colors.transparent,
);

/// Builds the app's single dark theme from [AppColors] and [AppTypography].
ThemeData buildDarkTheme() {
  final TextTheme text = AppTypography.textTheme;

  return ThemeData(
    colorScheme: _scheme,
    fontFamily: AppTypography.fontFamily,
    textTheme: text,
    scaffoldBackgroundColor: AppColors.background,
    canvasColor: AppColors.background,
    splashFactory: InkRipple.splashFactory,
    iconTheme: const IconThemeData(
      color: AppColors.textSecondary,
      size: AppSizes.iconMd,
    ),
    appBarTheme: AppBarThemeData(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
      iconTheme: const IconThemeData(
        color: AppColors.textSecondary,
        size: AppSizes.iconMd,
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.borderSubtle,
      space: 1,
      thickness: 1,
    ),
    textButtonTheme: TextButtonThemeData(style: _textButtonStyle(text)),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: _outlinedButtonStyle(text),
    ),
    iconButtonTheme: IconButtonThemeData(style: _iconButtonStyle()),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      titleTextStyle: text.headlineSmall,
      contentTextStyle: text.bodyMedium?.copyWith(
        color: AppColors.textSecondary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: AppColors.surface,
      elevation: 0,
      modalElevation: 0,
      showDragHandle: true,
      dragHandleColor: AppColors.border,
      dragHandleSize: Size(36, 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.md)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.surfaceHigh,
      contentTextStyle: text.bodyMedium,
      actionTextColor: AppColors.accent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.accentSoft,
      indicatorShape: const StadiumBorder(),
      elevation: 0,
      height: 64,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
        final bool selected = states.contains(WidgetState.selected);
        return IconThemeData(
          size: AppSizes.iconLg,
          color: selected ? AppColors.accent : AppColors.textSecondary,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((
        Set<WidgetState> states,
      ) {
        final bool selected = states.contains(WidgetState.selected);
        return text.labelSmall!.copyWith(
          color: selected ? AppColors.textPrimary : AppColors.textSecondary,
        );
      }),
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s8,
        vertical: AppSpacing.s4,
      ),
      textStyle: text.bodySmall,
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: const Border.fromBorderSide(
          BorderSide(color: AppColors.border),
        ),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: AppColors.textSecondary,
      textColor: AppColors.textPrimary,
      titleTextStyle: text.titleMedium,
      subtitleTextStyle: text.bodySmall,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.accent,
      linearTrackColor: AppColors.surfaceHigh,
      circularTrackColor: Colors.transparent,
      linearMinHeight: 2,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.accent,
      selectionColor: AppColors.accentRing,
      selectionHandleColor: AppColors.accent,
    ),
  );
}

ButtonStyle _textButtonStyle(TextTheme text) {
  return ButtonStyle(
    foregroundColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
      return states.contains(WidgetState.disabled)
          ? AppColors.textFaint
          : AppColors.accent;
    }),
    overlayColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
      if (states.contains(WidgetState.pressed)) {
        return AppColors.accentRing;
      }
      if (states.contains(WidgetState.focused)) {
        return AppColors.accentSoft;
      }
      return Colors.transparent;
    }),
    textStyle: WidgetStatePropertyAll<TextStyle?>(text.labelLarge),
    padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
      EdgeInsets.symmetric(horizontal: AppSpacing.s12),
    ),
    minimumSize: const WidgetStatePropertyAll<Size>(Size(0, 40)),
    shape: WidgetStatePropertyAll<OutlinedBorder>(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xs)),
    ),
    animationDuration: AppDuration.fast,
  );
}

ButtonStyle _outlinedButtonStyle(TextTheme text) {
  return ButtonStyle(
    foregroundColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
      return states.contains(WidgetState.disabled)
          ? AppColors.textFaint
          : AppColors.textPrimary;
    }),
    backgroundColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
      return states.contains(WidgetState.pressed)
          ? AppColors.surfaceHigh
          : Colors.transparent;
    }),
    overlayColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
    side: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
      return BorderSide(
        color: states.contains(WidgetState.disabled)
            ? AppColors.borderSubtle
            : AppColors.border,
      );
    }),
    textStyle: WidgetStatePropertyAll<TextStyle?>(text.labelLarge),
    padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
      EdgeInsets.symmetric(horizontal: AppSpacing.s16),
    ),
    minimumSize: const WidgetStatePropertyAll<Size>(Size(0, 40)),
    shape: WidgetStatePropertyAll<OutlinedBorder>(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
    ),
    animationDuration: AppDuration.fast,
  );
}

ButtonStyle _iconButtonStyle() {
  return ButtonStyle(
    foregroundColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
      if (states.contains(WidgetState.disabled)) {
        return AppColors.textFaint;
      }
      if (states.contains(WidgetState.focused)) {
        return AppColors.textPrimary;
      }
      return AppColors.textSecondary;
    }),
    backgroundColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
      return states.contains(WidgetState.pressed)
          ? AppColors.overlayPressed
          : Colors.transparent;
    }),
    overlayColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
    animationDuration: AppDuration.fast,
  );
}
