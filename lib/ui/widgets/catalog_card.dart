import 'package:flutter/material.dart';

import '../../domain/entities/catalog_anime.dart';
import '../../l10n/l10n.dart';
import '../theme/app_theme.dart';
import 'cover_image.dart';
import 'poster_card.dart';

/// Poster for a catalog search result.
///
/// When [inLibrary], the cover is dimmed and labeled but stays tappable, so
/// the detail screen can still be opened to change the status.
class CatalogCard extends StatelessWidget {
  const CatalogCard({
    required this.anime,
    this.inLibrary = false,
    this.onOpen,
    super.key,
  });

  final CatalogAnime anime;
  final bool inLibrary;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return PosterCard(
      cover: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          CoverImage(url: anime.coverUrl),
          if (inLibrary) ...<Widget>[
            const DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(AppRadius.sm)),
                color: AppOverlays.dim,
              ),
            ),
            Positioned(
              left: AppSpacing.s4,
              top: AppSpacing.s4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: context.palette.accent,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s8,
                    vertical: AppSpacing.s2,
                  ),
                  child: Text(
                    context.l10n.catalogCardInLibrary,
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: context.palette.onAccent),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      title: anime.title,
      onTap: onOpen,
    );
  }
}
