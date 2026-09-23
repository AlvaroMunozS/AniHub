import 'package:flutter/material.dart';

import 'tokens.dart';

/// Type scale on Inter.
///
/// Inter ships as a single variable font, so weights are set through the
/// `wght` axis. `fontWeight` is set too, so that system fallback fonts used
/// for glyphs Inter lacks, such as Japanese titles, match the weight. The
/// `opsz` axis follows the font size. Styles carry no color: `buildTheme`
/// colors them from the palette.
class AppTypography {
  const AppTypography._();

  static const String fontFamily = 'Inter';

  /// Range of Inter's `opsz` axis.
  static const double _opszMin = 14;
  static const double _opszMax = 32;

  static TextStyle _style({
    required double size,
    required FontWeight weight,
    double letterSpacing = 0,
    double height = 1.25,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: size,
      height: height,
      letterSpacing: letterSpacing,
      fontWeight: weight,
      fontVariations: <FontVariation>[
        FontVariation('wght', weight.value.toDouble()),
        FontVariation('opsz', size.clamp(_opszMin, _opszMax).toDouble()),
      ],
    );
  }

  /// Secondary text under a title. Callers color it with
  /// [AppPalette.textFaint].
  static final TextStyle caption = _style(
    size: 12,
    weight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.35,
  );

  /// Defines every Material style so no component falls back to the baseline.
  static final TextTheme textTheme = TextTheme(
    displayLarge: _style(size: 40, weight: FontWeight.w600, letterSpacing: -1),
    displayMedium: _style(
      size: 32,
      weight: FontWeight.w600,
      letterSpacing: -0.8,
    ),
    displaySmall: _style(
      size: 28,
      weight: FontWeight.w600,
      letterSpacing: -0.6,
    ),
    headlineLarge: _style(
      size: 26,
      weight: FontWeight.w600,
      letterSpacing: -0.5,
    ),
    headlineMedium: _style(
      size: 22,
      weight: FontWeight.w600,
      letterSpacing: -0.4,
    ),
    headlineSmall: _style(
      size: 18,
      weight: FontWeight.w600,
      letterSpacing: -0.2,
    ),
    titleLarge: _style(size: 20, weight: FontWeight.w600, letterSpacing: -0.3),
    titleMedium: _style(
      size: 15,
      weight: FontWeight.w600,
      letterSpacing: -0.1,
      height: 1.3,
    ),
    titleSmall: _style(size: 13, weight: FontWeight.w600),
    bodyLarge: _style(size: 15, weight: FontWeight.w400, height: 1.45),
    bodyMedium: _style(size: 14, weight: FontWeight.w400, height: 1.45),
    bodySmall: _style(size: 12, weight: FontWeight.w400, height: 1.4),
    labelLarge: _style(size: 14, weight: FontWeight.w600, letterSpacing: 0.1),
    labelMedium: _style(size: 13, weight: FontWeight.w500),
    labelSmall: _style(size: 12, weight: FontWeight.w500, letterSpacing: 0.2),
  );
}
