import 'package:flutter/material.dart';

import '../../domain/entities/entry.dart';
import 'cover_image.dart';
import 'poster_card.dart';

class EntryCard extends StatelessWidget {
  const EntryCard({required this.entry, this.onOpen, super.key});

  final Entry entry;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return PosterCard(
      cover: CoverImage(url: entry.coverUrl),
      title: entry.title,
      onTap: onOpen,
    );
  }
}
