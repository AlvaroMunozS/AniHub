import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_theme.dart';

/// Clamps the synopsis to a few faded lines that expand on tap. Text that
/// already fits is shown in full and ignores taps.
class ExpandableSynopsis extends StatefulWidget {
  const ExpandableSynopsis({required this.text, super.key});

  final String text;

  @override
  State<ExpandableSynopsis> createState() => _ExpandableSynopsisState();
}

class _ExpandableSynopsisState extends State<ExpandableSynopsis> {
  static const int _collapsedLines = 5;

  bool _expanded = false;

  bool _overflows(TextStyle style, double maxWidth) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: widget.text, style: style),
      maxLines: _collapsedLines,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: maxWidth);
    final bool overflows = painter.didExceedMaxLines;
    painter.dispose();
    return overflows;
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle style = Theme.of(context).textTheme.bodyMedium!;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (!_overflows(style, constraints.maxWidth)) {
          return Text(widget.text, style: style);
        }

        return Semantics(
          button: true,
          expanded: _expanded,
          onTapHint: _expanded
              ? context.l10n.detailShowLess
              : context.l10n.detailShowMore,
          child: GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (_expanded)
                  Text(widget.text, style: style)
                else
                  ShaderMask(
                    shaderCallback: (Rect bounds) => const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        Colors.white,
                        Colors.white,
                        Colors.transparent,
                      ],
                      stops: <double>[0, 0.75, 1],
                    ).createShader(bounds),
                    blendMode: BlendMode.dstIn,
                    child: Text(
                      widget.text,
                      style: style,
                      maxLines: _collapsedLines,
                      overflow: TextOverflow.clip,
                    ),
                  ),
                const SizedBox(height: AppSpacing.s4),
                Center(
                  child: Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: context.palette.textFaint,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
