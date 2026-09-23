import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../../domain/entities/entry.dart';
import '../../../l10n/l10n.dart';
import '../../theme/app_theme.dart';

/// The details screen's top bar, with a back button and, for a library
/// entry, a remove button.
///
/// Its background fades in with [opacity], so a scroll frame rebuilds the
/// bar alone.
class DetailTopBar extends StatelessWidget {
  const DetailTopBar({
    required this.topInset,
    required this.opacity,
    required this.entry,
    required this.onBack,
    required this.onRemove,
    super.key,
  });

  final double topInset;
  final ValueListenable<double> opacity;
  final Entry? entry;
  final VoidCallback onBack;
  final Future<void> Function(Entry entry) onRemove;

  @override
  Widget build(BuildContext context) {
    final Entry? entry = this.entry;
    return ValueListenableBuilder<double>(
      valueListenable: opacity,
      builder: (BuildContext context, double t, _) {
        return Container(
          height: topInset + AppSizes.headerHeight,
          padding: EdgeInsets.only(top: topInset),
          color: context.palette.background.withValues(alpha: t),
          child: Row(
            children: <Widget>[
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back, size: AppSizes.iconMd),
                tooltip: context.l10n.detailBack,
                color: context.palette.textPrimary,
                visualDensity: VisualDensity.compact,
              ),
              const Spacer(),
              if (entry != null)
                IconButton(
                  onPressed: () => unawaited(onRemove(entry)),
                  icon: const Icon(Icons.delete_outline, size: AppSizes.iconMd),
                  tooltip: context.l10n.detailRemove,
                  color: context.palette.textPrimary,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        );
      },
    );
  }
}
