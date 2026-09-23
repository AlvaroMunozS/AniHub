import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;

import 'accents.dart';
import 'tokens.dart';
import 'typography.dart';

// Re-exported so that widgets only need to import the theme.
export 'accents.dart';
export 'tokens.dart';
export 'typography.dart';

/// Sets every role explicitly, because roles left to `ColorScheme.dark` or
/// `ColorScheme.light` fall back to Material's baseline teal and purple. Roles
/// the app does not use point to palette neutrals.
ColorScheme _scheme(Brightness brightness, AppPalette p) {
  return ColorScheme(
    brightness: brightness,
    primary: p.accent,
    onPrimary: p.onAccent,
    primaryContainer: p.surfaceHigh,
    onPrimaryContainer: p.accent,
    secondary: p.textSecondary,
    onSecondary: p.background,
    secondaryContainer: p.surfaceHigh,
    onSecondaryContainer: p.textPrimary,
    tertiary: p.success,
    onTertiary: p.background,
    tertiaryContainer: p.surfaceHigh,
    onTertiaryContainer: p.success,
    error: p.danger,
    onError: p.background,
    errorContainer: p.dangerSoft,
    onErrorContainer: p.danger,
    surface: p.surface,
    onSurface: p.textPrimary,
    onSurfaceVariant: p.textSecondary,
    surfaceDim: p.background,
    surfaceBright: p.surfaceHigh,
    surfaceContainerLowest: p.background,
    surfaceContainerLow: p.surface,
    surfaceContainer: p.surface,
    surfaceContainerHigh: p.surfaceHigh,
    surfaceContainerHighest: p.surfaceHigh,
    outline: p.border,
    outlineVariant: p.borderSubtle,
    shadow: Colors.black,
    scrim: AppOverlays.scrim,
    inverseSurface: p.textPrimary,
    onInverseSurface: p.background,
    inversePrimary: p.accentPressed,
    surfaceTint: Colors.transparent,
  );
}

/// Builds the app theme for [brightness] from [AppPalette] and
/// [AppTypography]. [pureBlack] only applies to the dark theme.
ThemeData buildTheme({
  required Brightness brightness,
  required bool pureBlack,
  required AppAccent accent,
}) {
  final AppPalette p = switch (brightness) {
    Brightness.light => AppPalette.light(accent),
    Brightness.dark when pureBlack => AppPalette.pureBlack(accent),
    Brightness.dark => AppPalette.dark(accent),
  };
  final TextTheme base = AppTypography.textTheme.apply(
    bodyColor: p.textPrimary,
    displayColor: p.textPrimary,
  );
  final TextTheme text = base.copyWith(
    bodySmall: base.bodySmall!.copyWith(color: p.textSecondary),
  );

  return ThemeData(
    colorScheme: _scheme(brightness, p),
    extensions: <ThemeExtension<dynamic>>[p],
    fontFamily: AppTypography.fontFamily,
    textTheme: text,
    scaffoldBackgroundColor: p.background,
    canvasColor: p.background,
    splashFactory: InkRipple.splashFactory,
    iconTheme: IconThemeData(color: p.textSecondary, size: AppSizes.iconMd),
    appBarTheme: AppBarThemeData(
      backgroundColor: p.background,
      foregroundColor: p.textPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
      systemOverlayStyle: systemOverlayStyleFor(brightness),
      iconTheme: IconThemeData(color: p.textSecondary, size: AppSizes.iconMd),
    ),
    dividerTheme: DividerThemeData(
      color: p.borderSubtle,
      space: 1,
      thickness: 1,
    ),
    textButtonTheme: TextButtonThemeData(style: _textButtonStyle(text, p)),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: _outlinedButtonStyle(text, p),
    ),
    iconButtonTheme: IconButtonThemeData(style: _iconButtonStyle(p)),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      titleTextStyle: text.headlineSmall,
      contentTextStyle: text.bodyMedium?.copyWith(color: p.textSecondary),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: p.border),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: p.surface,
      elevation: 0,
      modalElevation: 0,
      showDragHandle: true,
      dragHandleColor: p.border,
      dragHandleSize: const Size(36, 4),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.md)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.surfaceHigh,
      contentTextStyle: text.bodyMedium,
      actionTextColor: p.accent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        side: BorderSide(color: p.border),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: p.accentSoft,
      indicatorShape: const StadiumBorder(),
      elevation: 0,
      height: 64,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
        final bool selected = states.contains(WidgetState.selected);
        return IconThemeData(
          size: AppSizes.iconLg,
          color: selected ? p.accent : p.textSecondary,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((
        Set<WidgetState> states,
      ) {
        final bool selected = states.contains(WidgetState.selected);
        return text.labelSmall!.copyWith(
          color: selected ? p.textPrimary : p.textSecondary,
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
        color: p.surfaceHigh,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.fromBorderSide(BorderSide(color: p.border)),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: p.textSecondary,
      textColor: p.textPrimary,
      titleTextStyle: text.titleMedium,
      subtitleTextStyle: text.bodySmall,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: p.accent,
      linearTrackColor: p.surfaceHigh,
      circularTrackColor: Colors.transparent,
      linearMinHeight: 2,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: p.accent,
      selectionColor: p.accentRing,
      selectionHandleColor: p.accent,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: _segmentedButtonStyle(text, p),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) return p.border;
        return states.contains(WidgetState.selected) ? p.onAccent : p.textFaint;
      }),
      trackColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.selected) &&
            !states.contains(WidgetState.disabled)) {
          return p.accent;
        }
        return p.surfaceHigh;
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith((
        Set<WidgetState> states,
      ) {
        return states.contains(WidgetState.selected) &&
                !states.contains(WidgetState.disabled)
            ? Colors.transparent
            : p.border;
      }),
    ),
  );
}

/// Status and navigation bar icons that stay legible over a background of
/// [brightness]. The bars themselves are transparent.
SystemUiOverlayStyle systemOverlayStyleFor(Brightness brightness) {
  final Brightness icons = brightness == Brightness.dark
      ? Brightness.light
      : Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: icons,
    statusBarBrightness: brightness,
    systemNavigationBarIconBrightness: icons,
  );
}

ButtonStyle _segmentedButtonStyle(TextTheme text, AppPalette p) {
  return ButtonStyle(
    foregroundColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
      if (states.contains(WidgetState.disabled)) return p.textFaint;
      return states.contains(WidgetState.selected) ? p.accent : p.textSecondary;
    }),
    backgroundColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
      return states.contains(WidgetState.selected)
          ? p.accentSoft
          : Colors.transparent;
    }),
    overlayColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
      return states.contains(WidgetState.pressed)
          ? p.overlayPressed
          : Colors.transparent;
    }),
    side: WidgetStatePropertyAll<BorderSide>(BorderSide(color: p.border)),
    textStyle: WidgetStatePropertyAll<TextStyle?>(text.labelLarge),
    shape: WidgetStatePropertyAll<OutlinedBorder>(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
    ),
    animationDuration: AppDuration.fast,
  );
}

ButtonStyle _textButtonStyle(TextTheme text, AppPalette p) {
  return ButtonStyle(
    foregroundColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
      return states.contains(WidgetState.disabled) ? p.textFaint : p.accent;
    }),
    overlayColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
      if (states.contains(WidgetState.pressed)) {
        return p.accentRing;
      }
      if (states.contains(WidgetState.focused)) {
        return p.accentSoft;
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

ButtonStyle _outlinedButtonStyle(TextTheme text, AppPalette p) {
  return ButtonStyle(
    foregroundColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
      return states.contains(WidgetState.disabled)
          ? p.textFaint
          : p.textPrimary;
    }),
    backgroundColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
      return states.contains(WidgetState.pressed)
          ? p.surfaceHigh
          : Colors.transparent;
    }),
    overlayColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
    side: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
      return BorderSide(
        color: states.contains(WidgetState.disabled)
            ? p.borderSubtle
            : p.border,
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

ButtonStyle _iconButtonStyle(AppPalette p) {
  return ButtonStyle(
    foregroundColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
      if (states.contains(WidgetState.disabled)) {
        return p.textFaint;
      }
      if (states.contains(WidgetState.focused)) {
        return p.textPrimary;
      }
      return p.textSecondary;
    }),
    backgroundColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
      return states.contains(WidgetState.pressed)
          ? p.overlayPressed
          : Colors.transparent;
    }),
    overlayColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
    animationDuration: AppDuration.fast,
  );
}
