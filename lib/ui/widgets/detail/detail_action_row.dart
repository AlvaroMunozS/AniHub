import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/catalog_anime.dart';
import '../../../domain/entities/entry.dart';
import '../../../domain/values/watch_status.dart';
import '../../../l10n/l10n.dart';
import '../../actions/add_to_library.dart';
import '../../actions/entry_actions.dart';
import '../../theme/app_theme.dart';
import '../status_selector.dart';

/// Wide enough for "Completado" in `labelMedium` without clipping.
const double _statusSlotWidth = 88;

const double _favoriteMinWidth = 72;

/// The status selector and favorite toggle of an anime.
///
/// The status selector takes half the row when collapsed. Expanded, it grows
/// into the favorite slot, which shrinks down to [_favoriteMinWidth].
///
/// Both controls stay disabled while an anime outside the library is being
/// added.
class DetailActionRow extends ConsumerWidget {
  const DetailActionRow({required this.anime, required this.entry, super.key});

  final CatalogAnime anime;
  final Entry? entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool pendingAdd =
        entry == null && ref.watch(pendingAddsProvider).contains(anime.malId);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        0,
        AppSpacing.s16,
        AppSpacing.s8,
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double collapsedWidth = constraints.maxWidth / 2;
          final double expandedWidth =
              (_statusSlotWidth * WatchStatus.values.length)
                  .clamp(
                    0.0,
                    math.max(0.0, constraints.maxWidth - _favoriteMinWidth),
                  )
                  .toDouble();
          return Row(
            children: <Widget>[
              _StatusAction(
                anime: anime,
                entry: entry,
                enabled: !pendingAdd,
                collapsedWidth: collapsedWidth,
                expandedWidth: expandedWidth,
              ),
              Expanded(
                child: _FavoriteAction(
                  anime: anime,
                  entry: entry,
                  enabled: !pendingAdd,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatusAction extends ConsumerWidget {
  const _StatusAction({
    required this.anime,
    required this.entry,
    required this.enabled,
    required this.collapsedWidth,
    required this.expandedWidth,
  });

  final CatalogAnime anime;
  final Entry? entry;
  final bool enabled;
  final double collapsedWidth;
  final double expandedWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Entry? entry = this.entry;
    return StatusSelector(
      current: entry?.status,
      collapsedWidth: collapsedWidth,
      expandedWidth: expandedWidth,
      enabled: enabled,
      onSelected: (WatchStatus status) => entry == null
          ? unawaited(addToLibrary(ref, context, anime, status: status))
          : unawaited(changeStatus(ref, context, entry, status)),
    );
  }
}

/// Toggles the favorite flag. An anime outside the library is added as
/// completed and favorite in one tap, since a favorite is always completed.
class _FavoriteAction extends ConsumerWidget {
  const _FavoriteAction({
    required this.anime,
    required this.entry,
    required this.enabled,
  });

  final CatalogAnime anime;
  final Entry? entry;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Entry? entry = this.entry;
    final bool isFavorite = entry?.isFavorite ?? false;
    return Semantics(
      toggled: isFavorite,
      child: StatusActionButton(
        icon: isFavorite ? Icons.favorite : Icons.favorite_border,
        label: context.l10n.detailFavorite,
        color: isFavorite
            ? context.palette.accent
            : context.palette.textSecondary,
        tooltip: isFavorite
            ? context.l10n.detailRemoveFavorite
            : context.l10n.detailAddFavorite,
        onTap: !enabled
            ? null
            : () => unawaited(
                entry == null
                    ? addToLibrary(
                        ref,
                        context,
                        anime,
                        status: WatchStatus.completed,
                        isFavorite: true,
                      )
                    : toggleFavorite(ref, context, entry),
              ),
      ),
    );
  }
}
