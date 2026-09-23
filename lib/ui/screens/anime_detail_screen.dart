import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart'
    show FutureProviderFamily, KeepAliveLink;
import 'package:go_router/go_router.dart';

import '../../domain/entities/anime_relation.dart';
import '../../domain/entities/anime_relation_node.dart';
import '../../domain/entities/catalog_anime.dart';
import '../../domain/entities/entry.dart';
import '../../domain/errors/catalog_exception.dart';
import '../../domain/values/relation_kind.dart';
import '../../domain/values/watch_status.dart';
import '../../l10n/l10n.dart';
import '../actions/add_to_library.dart';
import '../actions/entry_actions.dart';
import '../catalog_messages.dart';
import '../format/anime_meta.dart';
import '../providers.dart';
import '../report_error.dart';
import '../router.dart';
import '../state/library_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/cover_image.dart';
import '../widgets/empty_state.dart';
import '../widgets/skeleton.dart';
import '../widgets/status_selector.dart';

/// How long a visited anime stays cached after its last listener leaves:
/// revisits are instant without holding every visited anime in memory.
const Duration _detailCacheDuration = Duration(minutes: 10);

void _keepAliveFor(Ref ref, Duration duration) {
  final KeepAliveLink link = ref.keepAlive();
  final Timer timer = Timer(duration, link.close);
  ref.onDispose(timer.cancel);
}

/// Fetches an anime's catalog metadata by id.
final FutureProviderFamily<CatalogAnime, int> animeByIdProvider = FutureProvider
    .autoDispose
    .family<CatalogAnime, int>((Ref ref, int malId) {
      _keepAliveFor(ref, _detailCacheDuration);
      return reportingUnexpected(
        ref.watch(animeCatalogProvider).byId(malId),
        isExpected: _isCatalogError,
      );
    });

/// Fetches the relation graph node of an anime.
///
/// Shares the cached port with [libraryRelationsProvider], so opening a
/// detail screen also warms the library's snapshot.
final FutureProviderFamily<AnimeRelationNode?, int> animeRelationsByIdProvider =
    FutureProvider.autoDispose.family<AnimeRelationNode?, int>((
      Ref ref,
      int malId,
    ) async {
      _keepAliveFor(ref, _detailCacheDuration);
      final Map<int, AnimeRelationNode> result = await reportingUnexpected(
        ref.watch(animeRelationsProvider).forIds(<int>[malId]),
        isExpected: _isCatalogError,
      );
      return result[malId];
    });

bool _isCatalogError(Object error) => error is CatalogException;

const double _coverWidth = 110;
const double _relationCoverWidth = 40;

/// Wide enough for "Completado" in `labelMedium` without clipping.
const double _statusSlotWidth = 88;

const double _favoriteMinWidth = 72;

/// Shows an anime's catalog metadata together with its library controls,
/// in a scrollable layout under a pinned top bar.
///
/// Status, favorite and removal changes go through [PendingEntryChanges]:
/// they render immediately and roll back with a [SnackBar] if the write
/// fails.
///
/// The top bar turns fully opaque exactly when the header and action row
/// have scrolled out of view. Their height is measured after each layout,
/// and scrolling only updates a [ValueNotifier], so a scroll frame rebuilds
/// the bar alone.
class AnimeDetailScreen extends ConsumerStatefulWidget {
  const AnimeDetailScreen({required this.malId, super.key});

  final int malId;

  @override
  ConsumerState<AnimeDetailScreen> createState() => _AnimeDetailScreenState();
}

class _AnimeDetailScreenState extends ConsumerState<AnimeDetailScreen> {
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _barOpacity = ValueNotifier<double>(0);
  final GlobalKey _headerKey = GlobalKey();
  double? _fadeEnd;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateOpacity);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateOpacity);
    _scrollController.dispose();
    _barOpacity.dispose();
    super.dispose();
  }

  void _measure(double topInset) {
    final double? height = _headerKey.currentContext?.size?.height;
    if (height == null) return;
    final double next = (height - (topInset + AppSizes.headerHeight)).clamp(
      1,
      double.infinity,
    );
    if (_fadeEnd != next) {
      _fadeEnd = next;
      _updateOpacity();
    }
  }

  void _updateOpacity() {
    final double? fadeEnd = _fadeEnd;
    if (fadeEnd == null || !_scrollController.hasClients) return;
    _barOpacity.value = (_scrollController.offset / fadeEnd).clamp(0, 1);
  }

  Future<void> _remove(Entry entry) async {
    final bool removed = await removeFromLibrary(ref, context, entry);
    if (removed && mounted) _leaveDetail(context);
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<CatalogAnime> anime = ref.watch(
      animeByIdProvider(widget.malId),
    );
    final Entry? entry = _entryFor(
      ref.watch(visibleLibraryEntriesProvider).asData?.value,
      widget.malId,
    );
    final double topInset = MediaQuery.paddingOf(context).top;
    final double bottomInset = MediaQuery.paddingOf(context).bottom;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _measure(topInset);
    });

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlayStyleFor(Theme.of(context).brightness),
      child: Scaffold(
        body: Stack(
          children: <Widget>[
            CustomScrollView(
              controller: _scrollController,
              slivers: <Widget>[
                ..._contentSlivers(anime, entry, topInset),
                SliverToBoxAdapter(
                  child: SizedBox(height: bottomInset + AppSpacing.s48),
                ),
              ],
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _TopBar(
                topInset: topInset,
                opacity: _barOpacity,
                entry: entry,
                onRemove: _remove,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _contentSlivers(
    AsyncValue<CatalogAnime> anime,
    Entry? entry,
    double topInset,
  ) {
    return anime.when(
      loading: () => <Widget>[
        SliverToBoxAdapter(
          child: _DetailSkeleton(key: _headerKey, topInset: topInset),
        ),
      ],
      error: (Object error, StackTrace _) {
        final EmptyState notice = EmptyState(
          icon: catalogErrorIcon(error),
          title: context.l10n.detailLoadFailed,
          message: catalogErrorMessage(context.l10n, error),
          actionLabel: context.l10n.commonRetry,
          onAction: () => ref.invalidate(animeByIdProvider(widget.malId)),
        );
        if (entry == null) {
          return <Widget>[
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: EdgeInsets.only(top: topInset + AppSizes.headerHeight),
                child: notice,
              ),
            ),
          ];
        }
        // A library entry keeps its controls offline, built from the data
        // stored with the entry. The notice goes below them so the header
        // still starts at the top, where the top bar fade is measured from.
        final CatalogAnime fallback = CatalogAnime(
          malId: entry.malId,
          title: entry.title,
          coverUrl: entry.coverUrl,
          totalEpisodes: entry.totalEpisodes,
        );
        return <Widget>[
          SliverToBoxAdapter(
            child: _HeaderAndActions(
              key: _headerKey,
              anime: fallback,
              entry: entry,
              topInset: topInset,
            ),
          ),
          SliverToBoxAdapter(child: notice),
        ];
      },
      data: (CatalogAnime data) => <Widget>[
        SliverToBoxAdapter(
          child: _HeaderAndActions(
            key: _headerKey,
            anime: data,
            entry: entry,
            topInset: topInset,
          ),
        ),
        SliverToBoxAdapter(
          child: _Body(anime: data, malId: widget.malId),
        ),
      ],
    );
  }
}

Entry? _entryFor(List<Entry>? library, int malId) {
  if (library == null) {
    return null;
  }
  for (final Entry e in library) {
    if (e.malId == malId) {
      return e;
    }
  }
  return null;
}

/// Pops the detail screen, or goes to the library when there is nothing to
/// pop, as when the detail route was the initial location.
void _leaveDetail(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(RoutePaths.library);
  }
}

Future<bool> _confirmRemove(BuildContext context) async {
  final bool? ok = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: Text(context.l10n.detailRemoveTitle),
      content: Text(context.l10n.detailRemoveMessage),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(context.l10n.commonCancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(context.l10n.detailRemove),
        ),
      ],
    ),
  );
  return ok ?? false;
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.topInset,
    required this.opacity,
    required this.entry,
    required this.onRemove,
  });

  final double topInset;
  final ValueListenable<double> opacity;
  final Entry? entry;
  final Future<void> Function(Entry entry) onRemove;

  Future<void> _confirmAndRemove(BuildContext context, Entry entry) async {
    if (await _confirmRemove(context)) await onRemove(entry);
  }

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
                onPressed: () => _leaveDetail(context),
                icon: const Icon(Icons.arrow_back, size: AppSizes.iconMd),
                tooltip: context.l10n.detailBack,
                color: context.palette.textPrimary,
                visualDensity: VisualDensity.compact,
              ),
              const Spacer(),
              if (entry != null)
                IconButton(
                  onPressed: () => unawaited(_confirmAndRemove(context, entry)),
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

/// Keeps the header and action row in one widget because their combined
/// height sets where the top bar becomes fully opaque.
class _HeaderAndActions extends StatelessWidget {
  const _HeaderAndActions({
    required this.anime,
    required this.entry,
    required this.topInset,
    super.key,
  });

  final CatalogAnime anime;
  final Entry? entry;
  final double topInset;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _Header(anime: anime, topInset: topInset),
        _ActionRow(anime: anime, entry: entry),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.anime, required this.topInset});

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
        Padding(
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
                width: _coverWidth,
                height: _coverWidth / AppSizes.posterAspectRatio,
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

/// The status selector takes half the row when collapsed. Expanded, it grows
/// into the favorite slot, which shrinks down to [_favoriteMinWidth].
///
/// Both controls stay disabled while an anime outside the library is being
/// added.
class _ActionRow extends ConsumerWidget {
  const _ActionRow({required this.anime, required this.entry});

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

class _Body extends StatelessWidget {
  const _Body({required this.anime, required this.malId});

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
            _ExpandableSynopsis(text: anime.description!),
          ],
          if (anime.genres.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.s12),
            Text(
              anime.genres.join(' · '),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          _Relations(malId: malId),
        ],
      ),
    );
  }
}

/// Clamps the synopsis to a few faded lines that expand on tap. Text that
/// already fits is shown in full and ignores taps.
class _ExpandableSynopsis extends StatefulWidget {
  const _ExpandableSynopsis({required this.text});

  final String text;

  @override
  State<_ExpandableSynopsis> createState() => _ExpandableSynopsisState();
}

class _ExpandableSynopsisState extends State<_ExpandableSynopsis> {
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

/// Lists prequels and sequels. Renders nothing while loading, on error or
/// without relations: the section is optional and never blocks the screen.
class _Relations extends ConsumerWidget {
  const _Relations({required this.malId});

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
      onTap: () => context.push(RoutePaths.animeDetail(relation.malId)),
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

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton({required this.topInset, super.key});

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
                width: _coverWidth,
                height: _coverWidth / AppSizes.posterAspectRatio,
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
