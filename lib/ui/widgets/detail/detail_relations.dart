import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/entities/anime_relation.dart';
import '../../../domain/entities/anime_relation_node.dart';
import '../../../domain/values/relation_kind.dart';
import '../../../l10n/l10n.dart';
import '../../router.dart';
import '../../state/anime_detail_providers.dart';
import '../../theme/app_theme.dart';
import '../cover_image.dart';

const double _relationCoverWidth = 40;

/// Lists prequels and sequels. Renders nothing while loading, on error or
/// without relations: the section is optional and never blocks the screen.
class DetailRelations extends ConsumerWidget {
  const DetailRelations({required this.malId, super.key});

  final int malId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AnimeRelationNode? node = ref
        .watch(animeRelationsByIdProvider(malId))
        .asData
        ?.value;
    if (node == null) return const SizedBox.shrink();

    final List<AnimeRelation> prequels = <AnimeRelation>[
      for (final AnimeRelation relation in node.relations)
        if (relation.kind == RelationKind.prequel) relation,
    ];
    final List<AnimeRelation> sequels = <AnimeRelation>[
      for (final AnimeRelation relation in node.relations)
        if (relation.kind == RelationKind.sequel) relation,
    ];
    if (prequels.isEmpty && sequels.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (prequels.isNotEmpty)
          _RelationGroup(
            label: context.l10n.detailPrequels(prequels.length),
            relations: prequels,
          ),
        if (sequels.isNotEmpty)
          _RelationGroup(
            label: context.l10n.detailSequels(sequels.length),
            relations: sequels,
          ),
      ],
    );
  }
}

class _RelationGroup extends StatelessWidget {
  const _RelationGroup({required this.label, required this.relations});

  final String label;
  final List<AnimeRelation> relations;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: context.palette.textFaint,
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          for (final AnimeRelation relation in relations)
            _RelationRow(relation: relation),
        ],
      ),
    );
  }
}

class _RelationRow extends StatelessWidget {
  const _RelationRow({required this.relation});

  final AnimeRelation relation;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      // Back returns to where the first detail was opened, not through each
      // related anime.
      onTap: () =>
          context.pushReplacement(RoutePaths.animeDetail(relation.malId)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
        child: Row(
          children: <Widget>[
            CoverImage(
              url: relation.coverUrl,
              width: _relationCoverWidth,
              height: _relationCoverWidth / AppSizes.posterAspectRatio,
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    relation.title,
                    style: Theme.of(context).textTheme.labelLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (relation.seasonYear != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.s2),
                    Text(
                      '${relation.seasonYear}',
                      style: AppTypography.caption.copyWith(
                        color: context.palette.textFaint,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: context.palette.textFaint),
          ],
        ),
      ),
    );
  }
}
