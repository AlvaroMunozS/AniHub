import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart'
    show FutureProviderFamily, KeepAliveLink;

import '../../domain/entities/anime_relation_node.dart';
import '../../domain/entities/catalog_anime.dart';
import '../../domain/errors/catalog_exception.dart';
import '../providers.dart';
import '../report_error.dart';
import 'library_providers.dart';

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
