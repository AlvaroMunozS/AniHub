import '../../domain/entities/anime_relation_node.dart';
import '../../domain/entities/entry.dart';
import '../../domain/values/watch_status.dart';
import 'franchises.dart';

/// Finds the entries of franchises the user has started.
class FindStartedEntries {
  const FindStartedEntries();

  /// Returns the MyAnimeList ids of the entries in [library] whose franchise
  /// (see [Franchises]) has a member being watched or completed.
  ///
  /// [library] must be the whole library rather than one tab, because the
  /// members of a franchise can sit in different statuses. A whole franchise
  /// is started or not, so the result never splits a group of
  /// `GroupLibrary`.
  Set<int> call(List<Entry> library, Map<int, AnimeRelationNode> relations) {
    final Franchises franchises = Franchises(library, relations);
    final Set<int> startedRoots = <int>{
      for (final Entry entry in library)
        if (entry.status == WatchStatus.watching ||
            entry.status == WatchStatus.completed)
          franchises.rootOf(entry.malId),
    };
    return <int>{
      for (final Entry entry in library)
        if (startedRoots.contains(franchises.rootOf(entry.malId))) entry.malId,
    };
  }
}
