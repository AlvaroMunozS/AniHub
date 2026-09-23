import 'package:flutter/material.dart';

import '../../../domain/entities/catalog_anime.dart';
import '../../theme/app_theme.dart';
import 'detail_relations.dart';
import 'expandable_synopsis.dart';

/// The synopsis, genres and relations of an anime, below its header.
class DetailBody extends StatelessWidget {
  const DetailBody({required this.anime, required this.malId, super.key});

  final CatalogAnime anime;
  final int malId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (anime.description != null) ...<Widget>[
            const SizedBox(height: AppSpacing.s8),
            ExpandableSynopsis(text: anime.description!),
          ],
          if (anime.genres.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.s12),
            Text(
              anime.genres.join(' · '),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          DetailRelations(malId: malId),
        ],
      ),
    );
  }
}
