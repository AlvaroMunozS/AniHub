import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'poster_card.dart';
import 'poster_grid_metrics.dart';
import 'skeleton.dart';

/// Poster grid without relayout animations, for search results and loading
/// skeletons.
class PosterGrid extends StatelessWidget {
  const PosterGrid({
    required this.itemCount,
    required this.itemBuilder,
    super.key,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    final TextStyle titleStyle = PosterCard.titleStyleOf(context);
    final TextScaler textScaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final GridMetrics metrics = GridMetrics.of(
          constraints.maxWidth,
          itemCount,
          titleStyle,
          textScaler,
        );
        return GridView.builder(
          padding: const EdgeInsets.only(bottom: AppSpacing.s24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: metrics.crossAxisCount,
            crossAxisSpacing: GridMetrics.crossAxisSpacing,
            mainAxisSpacing: GridMetrics.mainAxisSpacing,
            mainAxisExtent: metrics.cellHeight,
          ),
          itemCount: itemCount,
          itemBuilder: itemBuilder,
        );
      },
    );
  }
}

class PosterGridSkeleton extends StatelessWidget {
  const PosterGridSkeleton({super.key});

  static const int _placeholderCount = 6;

  @override
  Widget build(BuildContext context) {
    return PosterGrid(
      itemCount: _placeholderCount,
      itemBuilder: (BuildContext context, int index) {
        return const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(child: Skeleton(radius: AppRadius.sm)),
            SizedBox(height: AppSpacing.s8),
            Skeleton(height: 12),
            SizedBox(height: AppSpacing.s4),
            Skeleton(height: 10, width: 80),
          ],
        );
      },
    );
  }
}
