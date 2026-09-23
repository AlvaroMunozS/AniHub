import '../../domain/entities/anime_relation_node.dart';
import '../../domain/entities/entry.dart';
import '../../domain/values/release_date.dart';
import 'franchises.dart';
import 'library_item.dart';
import 'title_key.dart';

/// Groups library entries that belong to the same franchise.
class GroupLibrary {
  const GroupLibrary();

  /// Groups [entries] by franchise (see [Franchises]).
  ///
  /// [entries] must be ordered most recently updated first, as
  /// `EntryRepository` returns them. This is assumed, not checked.
  ///
  /// - Members are ordered by release date, oldest first. Members without a
  ///   known date go last; ties are broken by title, ignoring case and
  ///   diacritics (see [titleKey]), then by id.
  /// - Each group takes the position of its most recently updated member.
  ///   Its [LibraryGroupItem.key] is the lowest MyAnimeList id in the connected
  ///   component, which keeps it stable across calls.
  /// - A component with a single library entry yields a [LibraryEntryItem],
  ///   never a group of one.
  List<LibraryItem> call(
    List<Entry> entries,
    Map<int, AnimeRelationNode> relations,
  ) {
    if (relations.isEmpty || entries.length < 2) {
      return entries.map(LibraryEntryItem.new).toList();
    }

    final Franchises franchises = Franchises(entries, relations);

    final Map<int, List<Entry>> membersByRoot = <int, List<Entry>>{};
    for (final Entry entry in entries) {
      final int root = franchises.rootOf(entry.malId);
      membersByRoot.putIfAbsent(root, () => <Entry>[]).add(entry);
    }

    int compareMembers(Entry a, Entry b) {
      final int? keyA = _sortKeyFor(a, relations);
      final int? keyB = _sortKeyFor(b, relations);
      if (keyA == null && keyB != null) return 1;
      if (keyA != null && keyB == null) return -1;
      if (keyA != null && keyB != null && keyA != keyB) {
        return keyA.compareTo(keyB);
      }
      final String titleA = _titleFor(a, relations);
      final String titleB = _titleFor(b, relations);
      final int keyCompare = titleKey(titleA).compareTo(titleKey(titleB));
      if (keyCompare != 0) return keyCompare;
      final int titleCompare = titleA.compareTo(titleB);
      if (titleCompare != 0) return titleCompare;
      return a.malId.compareTo(b.malId);
    }

    final List<LibraryItem> result = <LibraryItem>[];
    final Set<int> emittedRoots = <int>{};
    for (final Entry entry in entries) {
      final int root = franchises.rootOf(entry.malId);
      if (!emittedRoots.add(root)) continue;
      final List<Entry> members = membersByRoot[root]!;
      if (members.length < 2) {
        result.add(LibraryEntryItem(members.single));
        continue;
      }
      final List<Entry> sorted = List<Entry>.of(members)..sort(compareMembers);
      result.add(
        LibraryGroupItem(
          key: root,
          label: _titleFor(sorted.first, relations),
          members: sorted,
        ),
      );
    }
    return result;
  }
}

int? _sortKeyFor(Entry entry, Map<int, AnimeRelationNode> relations) {
  final AnimeRelationNode? node = relations[entry.malId];
  if (node == null) return null;
  return node.startDate?.sortKey ?? ReleaseDate(year: node.seasonYear).sortKey;
}

String _titleFor(Entry entry, Map<int, AnimeRelationNode> relations) =>
    relations[entry.malId]?.title ?? entry.title;
