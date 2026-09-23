import 'package:anihub/ui/theme/app_theme.dart';
import 'package:anihub/ui/widgets/poster_grid_metrics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

final TextStyle _titleStyle = AppTypography.textTheme.titleSmall!;

void main() {
  test('fits three columns on common phone widths', () {
    for (final double width in <double>[360, 412, 430]) {
      // Minus the `ContentColumn` gutters.
      final double contentWidth = width - AppSpacing.s16 * 2;
      final GridMetrics metrics = GridMetrics.of(
        contentWidth,
        6,
        _titleStyle,
        TextScaler.noScaling,
      );
      expect(metrics.crossAxisCount, 3, reason: 'at $width px');
    }
  });

  test('grows the cell height with the system text scale', () {
    final GridMetrics normal = GridMetrics.of(
      328,
      1,
      _titleStyle,
      TextScaler.noScaling,
    );
    final GridMetrics scaled = GridMetrics.of(
      328,
      1,
      _titleStyle,
      const TextScaler.linear(2),
    );

    expect(scaled.cellHeight, greaterThan(normal.cellHeight));
    expect(scaled.cellWidth, normal.cellWidth);
  });
}
