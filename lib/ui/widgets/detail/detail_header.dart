import 'package:flutter/material.dart';

import '../../../domain/entities/catalog_anime.dart';
import '../../../l10n/l10n.dart';
import '../../format/anime_meta.dart';
import '../../shell/content_column.dart';
import '../../theme/app_theme.dart';
import '../cover_image.dart';
import 'detail_metrics.dart';

/// The cover, title and metadata of an anime over a faded copy of its cover.
///
/// The faded cover spans the full width, while the content is centered at a
/// readable width and starts below the top bar, at [topInset] plus the bar's
/// height.
class DetailHeader extends StatelessWidget {
  const DetailHeader({required this.anime, required this.topInset, super.key});

  final CatalogAnime anime;
  final double topInset;

  @override
  Widget build(BuildContext context) {
    final String? episodes = formatEpisodes(context.l10n, anime);
    final String? season = formatSeason(context.l10n, anime);

    return Stack(
      children: <Widget>[
        Positioned.fill(child: CoverImage(url: anime.coverUrl, radius: 0)),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const <double>[0, 0.6, 1],
                colors: <Color>[
                  context.palette.background.withValues(alpha: 0.55),
                  context.palette.background.withValues(alpha: 0.85),
                  context.palette.background,
                ],
              ),
            ),
          ),
        ),
        ContentColumn(
          maxWidth: AppLayout.readableMaxWidth,
          padded: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.s16,
              topInset + AppSizes.headerHeight,
              AppSpacing.s16,
              AppSpacing.s16,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CoverImage(
                  url: anime.coverUrl,
                  width: detailCoverWidth,
                  height: detailCoverWidth / AppSizes.posterAspectRatio,
                ),
                const SizedBox(width: AppSpacing.s16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        anime.title,
                        style: Theme.of(context).textTheme.headlineSmall,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.s12),
                      if (episodes != null)
                        _MetaRow(icon: Icons.tv_outlined, text: episodes),
                      if (season != null)
                        _MetaRow(
                          icon: Icons.calendar_today_outlined,
                          text: season,
                        ),
                      if (anime.studioName != null)
                        _MetaRow(
                          icon: Icons.palette_outlined,
                          text: anime.studioName!,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s8),
      child: Row(
        children: <Widget>[
          Icon(
            icon,
            size: AppSizes.iconSm,
            color: context.palette.textSecondary,
          ),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
