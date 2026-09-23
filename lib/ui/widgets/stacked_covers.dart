import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'cover_image.dart';

/// Size difference between a layer and the one behind it.
const double _inset = AppSpacing.s4;

const int _maxLayers = 3;

/// Stacks up to three franchise covers inside the box a single [CoverImage]
/// would take, so grouped and ungrouped cells measure the same.
///
/// The oldest cover sits in front, smallest and anchored bottom-left. Each
/// layer behind it is a little larger, up to the full box, and peeks out at
/// the top-right under a scrim.
class StackedCovers extends StatelessWidget {
  const StackedCovers({required this.urls, super.key});

  /// Group covers, oldest first.
  final List<String?> urls;

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) {
      return const CoverImage(url: null);
    }

    final List<String?> layers = urls.take(_maxLayers).toList();
    final int depthMax = layers.length - 1;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            for (int depth = depthMax; depth >= 0; depth--)
              _layer(
                url: layers[depth],
                isFront: depth == 0,
                shrink: _inset * (depthMax - depth),
                boxWidth: constraints.maxWidth,
                boxHeight: constraints.maxHeight,
              ),
          ],
        );
      },
    );
  }

  Widget _layer({
    required String? url,
    required bool isFront,
    required double shrink,
    required double boxWidth,
    required double boxHeight,
  }) {
    final double layerWidth = boxWidth - shrink;
    final double layerHeight = boxHeight - shrink;

    Widget cover = CoverImage(url: url, width: layerWidth, height: layerHeight);

    if (!isFront) {
      cover = Stack(
        fit: StackFit.expand,
        children: <Widget>[
          cover,
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.scrim,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.border),
            ),
          ),
        ],
      );
    }

    return Positioned(
      left: 0,
      top: shrink,
      width: layerWidth,
      height: layerHeight,
      child: cover,
    );
  }
}
