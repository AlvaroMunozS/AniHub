import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/catalog_anime.dart';
import '../../domain/entities/entry.dart';
import '../../l10n/l10n.dart';
import '../actions/entry_actions.dart';
import '../catalog_messages.dart';
import '../router.dart';
import '../state/anime_detail_providers.dart';
import '../state/library_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/detail/detail_action_row.dart';
import '../widgets/detail/detail_body.dart';
import '../widgets/detail/detail_header.dart';
import '../widgets/detail/detail_skeleton.dart';
import '../widgets/detail/detail_top_bar.dart';
import '../widgets/empty_state.dart';

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

  Future<void> _confirmAndRemove(Entry entry) async {
    if (!await _confirmRemove(context) || !mounted) return;
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
              child: DetailTopBar(
                topInset: topInset,
                opacity: _barOpacity,
                entry: entry,
                onBack: () => _leaveDetail(context),
                onRemove: _confirmAndRemove,
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
          child: DetailSkeleton(key: _headerKey, topInset: topInset),
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
          child: DetailBody(anime: data, malId: widget.malId),
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
        DetailHeader(anime: anime, topInset: topInset),
        DetailActionRow(anime: anime, entry: entry),
      ],
    );
  }
}
