import 'package:anihub/ui/theme/app_theme.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final Map<String, AppPalette Function(AppAccent)> modes =
      <String, AppPalette Function(AppAccent)>{
        'dark': AppPalette.dark,
        'pure black': AppPalette.pureBlack,
        'light': AppPalette.light,
      };

  for (final MapEntry<String, AppPalette Function(AppAccent)> mode
      in modes.entries) {
    for (final AppAccent accent in AppAccent.values) {
      final AppPalette palette = mode.value(accent);

      test('${accent.name} stands out from ${mode.key} surfaces', () {
        for (final Color surface in <Color>[
          palette.background,
          palette.surface,
          palette.surfaceHigh,
        ]) {
          expect(
            contrastRatio(palette.accent, surface),
            greaterThanOrEqualTo(3),
          );
        }
      });

      test('text on ${accent.name} is legible in ${mode.key}', () {
        expect(
          contrastRatio(palette.onAccent, palette.accent),
          greaterThanOrEqualTo(4.5),
        );
      });
    }
  }

  test('indigo keeps the original dark accent', () {
    expect(AppPalette.dark(AppAccent.indigo).accent, const Color(0xFF7D8AF5));
  });
}
