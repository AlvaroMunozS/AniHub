import 'package:flutter/material.dart';

import 'poster_card.dart';
import 'stacked_covers.dart';

/// Poster for a franchise group, built on [PosterCard] like the entry
/// posters so both cells measure the same.
class GroupCard extends StatelessWidget {
  const GroupCard({
    required this.label,
    required this.coverUrls,
    required this.expanded,
    this.onTap,
    super.key,
  });

  final String label;

  /// Member covers, oldest first.
  final List<String?> coverUrls;

  /// Whether the group's members are shown.
  final bool expanded;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PosterCard(
      cover: StackedCovers(urls: coverUrls),
      title: label,
      expanded: expanded,
      onTap: onTap,
    );
  }
}
