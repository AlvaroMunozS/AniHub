import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/catalog_anime.dart';
import '../../domain/entities/entry.dart';
import '../../domain/errors/catalog_exception.dart';
import '../../l10n/l10n.dart';
import '../catalog_messages.dart';
import '../providers.dart';
import '../report_error.dart';
import '../router.dart';
import '../shell/content_column.dart';
import '../state/library_providers.dart';
import '../widgets/catalog_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/pill_search_bar.dart';
import '../widgets/poster_grid.dart';

/// Searches the catalog as the user types.
///
/// Results already in the library are dimmed but stay tappable.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  static const Duration _debounceDelay = Duration(milliseconds: 350);

  final TextEditingController _query = TextEditingController();
  Timer? _debounce;
  bool _loading = false;
  int _requestId = 0;
  List<CatalogAnime> _results = <CatalogAnime>[];

  /// The failure of the last search, or null.
  Object? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, () => unawaited(_search(value)));
  }

  Future<void> _search(String value) async {
    final String term = value.trim();
    final int id = ++_requestId;
    if (term.length < ref.read(animeCatalogProvider).minQueryLength) {
      setState(() {
        _loading = false;
        _results = <CatalogAnime>[];
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    List<CatalogAnime> hits;
    try {
      hits = await ref.read(animeCatalogProvider).search(term);
    } on Object catch (error, stack) {
      if (error is! CatalogException) reportUiError(error, stack);
      _fail(id, error);
      return;
    }

    if (!mounted || id != _requestId) {
      return;
    }
    setState(() {
      _loading = false;
      _results = hits;
      _error = null;
    });
  }

  void _fail(int id, Object error) {
    if (!mounted || id != _requestId) {
      return;
    }
    setState(() {
      _loading = false;
      _results = <CatalogAnime>[];
      _error = error;
    });
  }

  void _clear() {
    _debounce?.cancel();
    _query.clear();
    unawaited(_search(''));
  }

  @override
  Widget build(BuildContext context) {
    final Set<int> inLibrary = <int>{
      ...?ref
          .watch(visibleLibraryEntriesProvider)
          .asData
          ?.value
          .map((Entry e) => e.malId),
    };

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ContentColumn(
            padded: false,
            child: PillSearchBar(
              controller: _query,
              hintText: context.l10n.searchHint,
              onChanged: _onQueryChanged,
              onClear: _clear,
            ),
          ),
          _LoadingLine(loading: _loading),
          Expanded(
            child: ContentColumn(
              alignment: Alignment.topCenter,
              child: _body(inLibrary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(Set<int> inLibrary) {
    final Object? error = _error;
    if (error != null) {
      return EmptyState(
        icon: catalogErrorIcon(error),
        title: context.l10n.searchFailed,
        message: catalogErrorMessage(context.l10n, error),
        actionLabel: context.l10n.commonRetry,
        onAction: () => unawaited(_search(_query.text)),
      );
    }
    if (_loading && _results.isEmpty) {
      return const PosterGridSkeleton();
    }
    final String term = _query.text.trim();
    if (_results.isEmpty) {
      final int minQueryLength = ref.read(animeCatalogProvider).minQueryLength;
      if (term.length < minQueryLength) {
        return EmptyState(
          icon: Icons.search,
          title: context.l10n.searchPromptTitle,
          message: context.l10n.searchPromptMessage(minQueryLength),
        );
      }
      return EmptyState(
        icon: Icons.search_off,
        title: context.l10n.commonNoResults,
        message: context.l10n.searchNothingMatching(term),
      );
    }
    return PosterGrid(
      itemCount: _results.length,
      itemBuilder: (BuildContext context, int index) {
        final CatalogAnime anime = _results[index];
        return CatalogCard(
          anime: anime,
          inLibrary: inLibrary.contains(anime.malId),
          onOpen: () => context.push(RoutePaths.animeDetail(anime.malId)),
        );
      },
    );
  }
}

class _LoadingLine extends StatelessWidget {
  const _LoadingLine({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 2,
      child: loading
          ? const LinearProgressIndicator()
          : const SizedBox.shrink(),
    );
  }
}
