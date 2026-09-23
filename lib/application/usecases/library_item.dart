import '../../domain/entities/entry.dart';
import '../../domain/support/list_equality.dart';

/// A top-level item of the grouped library: a single entry or a franchise
/// group.
sealed class LibraryItem {
  const LibraryItem();
}

/// An entry that is not grouped with any other.
class LibraryEntryItem extends LibraryItem {
  const LibraryEntryItem(this.entry);

  final Entry entry;

  @override
  bool operator ==(Object other) =>
      other is LibraryEntryItem && other.entry == entry;

  @override
  int get hashCode => entry.hashCode;

  @override
  String toString() => 'LibraryEntryItem(${entry.title})';
}

/// Two or more entries of the same franchise.
class LibraryGroupItem extends LibraryItem {
  LibraryGroupItem({
    required this.key,
    required this.label,
    required this.members,
  }) : assert(members.length >= 2, 'A group needs at least two members');

  /// Lowest MyAnimeList id in the franchise, stable across calls with the same
  /// data.
  final int key;

  /// Title of the earliest released member.
  final String label;

  /// Members ordered by release date, oldest first.
  final List<Entry> members;

  @override
  bool operator ==(Object other) =>
      other is LibraryGroupItem &&
      other.key == key &&
      other.label == label &&
      sameElements(other.members, members);

  @override
  int get hashCode => Object.hash(key, label, Object.hashAll(members));

  @override
  String toString() =>
      'LibraryGroupItem($key, $label, ${members.length} members)';
}
