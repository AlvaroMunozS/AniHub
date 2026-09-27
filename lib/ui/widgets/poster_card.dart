import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shared poster layout: a 2:3 [cover] with a bottom gradient, above a
/// two-line [title].
class PosterCard extends StatelessWidget {
  const PosterCard({
    required this.cover,
    required this.title,
    this.overlay,
    this.onTap,
    this.expanded,
    super.key,
  });

  final Widget cover;
  final String title;

  /// Drawn over the gradient, so text on it stays readable; usually a
  /// [Positioned] near the bottom.
  final Widget? overlay;

  final VoidCallback? onTap;

  /// Whether the group this poster toggles is expanded, or null for a poster
  /// that does not toggle a group.
  final bool? expanded;

  /// Style of the title, which the poster grids measure to size their cells.
  static TextStyle titleStyleOf(BuildContext context) =>
      Theme.of(context).textTheme.titleSmall!;

  /// Fixes the height of every title line to [style]'s, which the grids
  /// measure; a glyph from a fallback font, as in some Japanese titles, would
  /// otherwise make its line taller and overflow the cell.
  static StrutStyle titleStrutOf(TextStyle style) =>
      StrutStyle.fromTextStyle(style, forceStrutHeight: true);

  @override
  Widget build(BuildContext context) {
    final TextStyle titleStyle = titleStyleOf(context);
    return Semantics(
      button: true,
      expanded: expanded,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AspectRatio(
              aspectRatio: AppSizes.posterAspectRatio,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  cover,
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.all(
                        Radius.circular(AppRadius.sm),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.center,
                        end: Alignment.bottomCenter,
                        colors: <Color>[Colors.transparent, AppOverlays.scrim],
                      ),
                    ),
                  ),
                  ?overlay,
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              title,
              style: titleStyle,
              strutStyle: titleStrutOf(titleStyle),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
