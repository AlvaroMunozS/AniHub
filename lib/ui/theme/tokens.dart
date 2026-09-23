import 'package:flutter/widgets.dart';

/// Dark palette. Color comes from the cover art: the interface stays neutral,
/// with a single accent reserved for interactive elements.
class AppColors {
  const AppColors._();

  // Surfaces are separated by a luminance step and a 1 px border, never by
  // shadows.
  static const Color background = Color(0xFF0C0C0E);
  static const Color surface = Color(0xFF141416);
  static const Color surfaceHigh = Color(0xFF1C1C20);
  static const Color borderSubtle = Color(0xFF232327);
  static const Color border = Color(0xFF2E2E34);

  static const Color textPrimary = Color(0xFFF4F4F5);
  static const Color textSecondary = Color(0xFFA0A0AB);
  static const Color textFaint = Color(0xFF6B6B75);

  static const Color accent = Color(0xFF7D8AF5);
  static const Color accentPressed = Color(0xFF5F6BD0);
  static const Color onAccent = Color(0xFF0B0B12);

  static const Color accentSoft = Color(0x247D8AF5);

  static const Color accentRing = Color(0x4D7D8AF5);

  static const Color danger = Color(0xFFE5646B);
  static const Color dangerSoft = Color(0x1AE5646B);
  static const Color success = Color(0xFF6FB08A);

  static const Color overlayPressed = Color(0x1AFFFFFF);
  static const Color scrim = Color(0xB3000000);
  static const Color dim = Color(0x66000000);

  // Tint of the current status in StatusSelector.
  static const Color statusWatching = accent;
  static const Color statusPlanned = textSecondary;
  static const Color statusCompleted = success;
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
