import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../skeleton.dart';
import 'detail_metrics.dart';

/// Placeholder for the details header, action row and synopsis while the
/// anime loads.
class DetailSkeleton extends StatelessWidget {
  const DetailSkeleton({required this.topInset, super.key});

  final double topInset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.s16,
        topInset + AppSizes.headerHeight,
        AppSpacing.s16,
        AppSpacing.s16,
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Skeleton(
                width: detailCoverWidth,
                height: detailCoverWidth / AppSizes.posterAspectRatio,
                radius: AppRadius.sm,
              ),
              SizedBox(width: AppSpacing.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Skeleton(height: 20, width: 200),
                    SizedBox(height: AppSpacing.s12),
                    Skeleton(height: 14, width: 120),
                    SizedBox(height: AppSpacing.s8),
                    Skeleton(height: 14, width: 140),
                    SizedBox(height: AppSpacing.s8),
                    Skeleton(height: 14, width: 100),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.s16),
          Skeleton(height: 40),
          SizedBox(height: AppSpacing.s24),
          Skeleton(height: 12),
          SizedBox(height: AppSpacing.s8),
          Skeleton(height: 12),
          SizedBox(height: AppSpacing.s8),
          Skeleton(height: 12, width: 220),
        ],
      ),
    );
  }
}
