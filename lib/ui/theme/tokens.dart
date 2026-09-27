import 'dart:math' as math;

import 'package:flutter/material.dart' show Theme, ThemeExtension;
import 'package:flutter/widgets.dart';

import 'accents.dart';

/// Colors of the interface. Color comes from the cover art: the interface
/// stays neutral, with a single accent reserved for interactive elements.
///
/// Surfaces are separated by a luminance step and a 1 px border, never by
/// shadows. Read it with [PaletteContext.palette].
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceHigh,
    required this.borderSubtle,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textFaint,
    required this.accent,
    required this.onAccent,
    required this.danger,
    required this.success,
    required this.overlayPressed,
  });

  factory AppPalette.dark(AppAccent accent) {
    return AppPalette(
      background: const Color(0xFF0C0C0E),
      surface: const Color(0xFF141416),
      surfaceHigh: const Color(0xFF1C1C20),
      borderSubtle: _darkBorderSubtle,
      border: _darkBorder,
      textPrimary: _darkTextPrimary,
      textSecondary: _darkTextSecondary,
      textFaint: _darkTextFaint,
      accent: accent.dark,
      onAccent: onAccentFor(accent.dark),
      danger: _darkDanger,
      success: _darkSuccess,
      overlayPressed: const Color(0x1AFFFFFF),
    );
  }

  /// The dark palette over pure black surfaces, for OLED screens.
  factory AppPalette.pureBlack(AppAccent accent) {
    return AppPalette.dark(accent).copyWith(
      background: const Color(0xFF000000),
      surface: const Color(0xFF0B0B0C),
      surfaceHigh: const Color(0xFF151518),
    );
  }

  factory AppPalette.light(AppAccent accent) {
    return AppPalette(
      background: const Color(0xFFF7F7F8),
      surface: const Color(0xFFFFFFFF),
      surfaceHigh: const Color(0xFFEFEFF2),
      borderSubtle: const Color(0xFFE4E4E8),
      border: const Color(0xFFD4D4DA),
      textPrimary: const Color(0xFF17171A),
      textSecondary: const Color(0xFF5A5A64),
      textFaint: const Color(0xFF8A8A94),
      accent: accent.light,
      onAccent: onAccentFor(accent.light),
      danger: const Color(0xFFC8404A),
      success: const Color(0xFF2F8A57),
      overlayPressed: const Color(0x14000000),
    );
  }

  static const Color _darkBorderSubtle = Color(0xFF232327);
  static const Color _darkBorder = Color(0xFF2E2E34);
  static const Color _darkTextPrimary = Color(0xFFF4F4F5);
  static const Color _darkTextSecondary = Color(0xFFA0A0AB);
  static const Color _darkTextFaint = Color(0xFF6B6B75);
  static const Color _darkDanger = Color(0xFFE5646B);
  static const Color _darkSuccess = Color(0xFF6FB08A);

  static const Color _onAccentDark = Color(0xFF0B0B12);
  static const Color _onAccentLight = Color(0xFFFFFFFF);

  /// Returns the text color with the higher contrast on [accent].
  static Color onAccentFor(Color accent) {
    return contrastRatio(_onAccentDark, accent) >=
            contrastRatio(_onAccentLight, accent)
        ? _onAccentDark
        : _onAccentLight;
  }

  final Color background;
  final Color surface;
  final Color surfaceHigh;
  final Color borderSubtle;
  final Color border;

  final Color textPrimary;
  final Color textSecondary;
  final Color textFaint;

  final Color accent;
  final Color onAccent;

  final Color danger;
  final Color success;

  final Color overlayPressed;

  Color get accentPressed => Color.lerp(accent, const Color(0xFF000000), 0.2)!;
  Color get accentSoft => accent.withValues(alpha: 0.14);
  Color get accentRing => accent.withValues(alpha: 0.3);
  Color get dangerSoft => danger.withValues(alpha: 0.1);

  // Tint of the current status in StatusSelector.
  Color get statusWatching => accent;
  Color get statusPlanned => textSecondary;
  Color get statusCompleted => success;

  @override
  AppPalette copyWith({
    Color? background,
    Color? surface,
    Color? surfaceHigh,
    Color? borderSubtle,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textFaint,
    Color? accent,
    Color? onAccent,
    Color? danger,
    Color? success,
    Color? overlayPressed,
  }) {
    return AppPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceHigh: surfaceHigh ?? this.surfaceHigh,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textFaint: textFaint ?? this.textFaint,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      danger: danger ?? this.danger,
      success: success ?? this.success,
      overlayPressed: overlayPressed ?? this.overlayPressed,
    );
  }

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      background: mix(background, other.background),
      surface: mix(surface, other.surface),
      surfaceHigh: mix(surfaceHigh, other.surfaceHigh),
      borderSubtle: mix(borderSubtle, other.borderSubtle),
      border: mix(border, other.border),
      textPrimary: mix(textPrimary, other.textPrimary),
      textSecondary: mix(textSecondary, other.textSecondary),
      textFaint: mix(textFaint, other.textFaint),
      accent: mix(accent, other.accent),
      onAccent: mix(onAccent, other.onAccent),
      danger: mix(danger, other.danger),
      success: mix(success, other.success),
      overlayPressed: mix(overlayPressed, other.overlayPressed),
    );
  }
}

/// Overlays drawn over cover art, which is dark or light whatever the theme.
class AppOverlays {
  const AppOverlays._();

  static const Color scrim = Color(0xB3000000);
  static const Color dim = Color(0x66000000);

  /// Text over [scrim].
  static const Color onScrim = Color(0xFFFFFFFF);
}

extension PaletteContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}

/// WCAG 2 contrast ratio between two opaque colors, from 1 to 21.
double contrastRatio(Color a, Color b) {
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

class AppSpacing {
  const AppSpacing._();

  static const double s2 = 2;
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s48 = 48;
}

class AppRadius {
  const AppRadius._();

  static const double xs = 6;
  static const double sm = 10;
  static const double md = 14;
  static const double pill = 999;
}

/// Animation durations, all paired with the single app-wide [curve].
class AppDuration {
  const AppDuration._();

  static const Duration fast = Duration(milliseconds: 120);
  static const Duration base = Duration(milliseconds: 180);
  static const Duration slow = Duration(milliseconds: 260);

  /// Period of the loading skeleton pulse.
  static const Duration pulse = Duration(milliseconds: 1200);

  static const Curve curve = Curves.easeOutCubic;
}

class AppSizes {
  const AppSizes._();

  /// Height of the detail screen's top bar.
  static const double headerHeight = 52;

  /// Width to height ratio of a cover.
  static const double posterAspectRatio = 2 / 3;

  static const double iconSm = 16;

  /// Default size, set in the theme's `iconTheme`.
  static const double iconMd = 20;

  static const double iconLg = 24;
}

/// Maximum content widths, so layouts do not stretch across tablets and
/// landscape screens.
class AppLayout {
  const AppLayout._();

  static const double contentMaxWidth = 1080;

  /// For list and text screens, which read poorly when stretched.
  static const double readableMaxWidth = 720;
}
