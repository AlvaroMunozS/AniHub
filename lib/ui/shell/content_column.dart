import 'package:flutter/widgets.dart';

import '../theme/app_theme.dart';

/// Constrains [child] to a centered column at most [maxWidth] wide, so
/// content does not stretch across tablets and landscape screens.
class ContentColumn extends StatelessWidget {
  const ContentColumn({
    required this.child,
    this.maxWidth = AppLayout.contentMaxWidth,
    this.alignment = Alignment.center,
    super.key,
  });

  final Widget child;
  final double maxWidth;

  /// Use [Alignment.topCenter] when [child] does not fill the available
  /// height, as inside a `TabBarView`; otherwise short content floats in the
  /// middle of the screen.
  final Alignment alignment;

  /// Fixed at any screen width; [maxWidth] handles wide screens.
  static const double gutter = AppSpacing.s16;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth + gutter * 2),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: gutter),
          child: child,
        ),
      ),
    );
  }
}
