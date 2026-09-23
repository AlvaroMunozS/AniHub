import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shared poster layout: a 2:3 [cover] with a bottom gradient, above a
/// two-line [title].
class PosterCard extends StatelessWidget {
  const PosterCard({
    required this.cover,
    required this.title,
    this.onTap,
    this.expanded,
    super.key,
  });

  final Widget cover;
  final String title;
  final VoidCallback? onTap;

  /// Whether the group this poster toggles is expanded, or null for a poster
  /// that does not toggle a group.
  final bool? expanded;

  /// Style of the title, which the poster grids measure to size their cells.
  static TextStyle titleStyleOf(BuildContext context) =>
      Theme.of(context).textTheme.titleSmall!;

  @override
  Widget build(BuildContext context) {
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
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              title,
              style: titleStyleOf(context),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
