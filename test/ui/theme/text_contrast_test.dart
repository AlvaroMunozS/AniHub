import 'package:anihub/ui/theme/app_theme.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final Map<String, AppPalette> modes = <String, AppPalette>{
    'dark': AppPalette.dark(AppAccent.indigo),
    'pure black': AppPalette.pureBlack(AppAccent.indigo),
    'light': AppPalette.light(AppAccent.indigo),
  };

  for (final MapEntry<String, AppPalette> mode in modes.entries) {
    final AppPalette palette = mode.value;
    final Map<String, Color> surfaces = <String, Color>{
      'background': palette.background,
      'surface': palette.surface,
      'surfaceHigh': palette.surfaceHigh,
    };
    final Map<String, Color> texts = <String, Color>{
      'textPrimary': palette.textPrimary,
      'textSecondary': palette.textSecondary,
      'textFaint': palette.textFaint,
    };

    for (final MapEntry<String, Color> surface in surfaces.entries) {
      for (final MapEntry<String, Color> text in texts.entries) {
        test('${text.key} is legible on ${mode.key} ${surface.key}', () {
          expect(
            contrastRatio(text.value, surface.value),
            greaterThanOrEqualTo(4.5),
          );
        });
      }

      test('textFaint is fainter than textSecondary on ${mode.key} '
          '${surface.key}', () {
        expect(
          contrastRatio(palette.textFaint, surface.value),
          lessThan(contrastRatio(palette.textSecondary, surface.value)),
        );
      });
    }
  }
}
