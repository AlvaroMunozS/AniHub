import 'package:flutter/widgets.dart';

import '../theme/app_theme.dart';

/// Resolved geometry of a poster grid, shared by every poster grid so they
/// all line up.
///
/// Computes columns like [SliverGridDelegateWithMaxCrossAxisExtent], but by
/// hand, so that each cell can also be placed with [AnimatedPositioned].
class GridMetrics {
  const GridMetrics._({
    required this.crossAxisCount,
    required this.cellWidth,
    required this.cellHeight,
    required this.totalHeight,
  });

  /// Compact enough to fit three columns on common phone widths.
  static const double maxCrossAxisExtent = 130;
  static const double crossAxisSpacing = AppSpacing.s8;
  static const double mainAxisSpacing = AppSpacing.s16;

  final int crossAxisCount;
  final double cellWidth;
  final double cellHeight;
  final double totalHeight;

  /// Lays out [cellCount] cells across [maxWidth], leaving room under each
  /// cover for two lines of [titleStyle] scaled by [textScaler].
  factory GridMetrics.of(
    double maxWidth,
    int cellCount,
    TextStyle titleStyle,
    TextScaler textScaler,
  ) {
    final int rawCount = (maxWidth / (maxCrossAxisExtent + crossAxisSpacing))
        .ceil();
    final int crossAxisCount = rawCount < 1 ? 1 : rawCount;
    final double usable = maxWidth - crossAxisSpacing * (crossAxisCount - 1);
    final double cellWidth = usable / crossAxisCount;
    // The cover plus the measured title height rather than a fixed ratio, so
    // short titles leave no gap and larger system text does not overflow.
    final double cellHeight =
        cellWidth / AppSizes.posterAspectRatio +
        AppSpacing.s8 +
        _twoLineHeight(titleStyle, textScaler);
    final int rows = (cellCount + crossAxisCount - 1) ~/ crossAxisCount;
    final double totalHeight = rows == 0
        ? 0
        : rows * cellHeight + (rows - 1) * mainAxisSpacing;
    return GridMetrics._(
      crossAxisCount: crossAxisCount,
      cellWidth: cellWidth,
      cellHeight: cellHeight,
      totalHeight: totalHeight,
    );
  }

  Offset offsetFor(int index) {
    final int row = index ~/ crossAxisCount;
    final int col = index % crossAxisCount;
    return Offset(
      col * (cellWidth + crossAxisSpacing),
      row * (cellHeight + mainAxisSpacing),
    );
  }
}

double _twoLineHeight(TextStyle style, TextScaler textScaler) {
  final TextPainter painter = TextPainter(
    text: TextSpan(text: 'Ag\nAg', style: style),
    textDirection: TextDirection.ltr,
    textScaler: textScaler,
    maxLines: 2,
  )..layout();
  final double height = painter.height;
  painter.dispose();
  return height;
}
