import '../../domain/entities/entry.dart';
import 'group_library.dart';
import 'library_item.dart';
import 'library_order.dart';
import 'title_key.dart';

/// Orders the top-level items of the grouped library.
///
/// Runs after [GroupLibrary] because alphabetical order needs the label of
/// each group.
class SortLibrary {
  const SortLibrary();

  /// Returns [items] sorted by [order], in reverse when [reversed] is set.
  ///
  /// Only top-level items move; the members of each group keep their order.
  List<LibraryItem> call(
    List<LibraryItem> items,
    LibraryOrder order, {
    bool reversed = false,
  }) {
    final List<LibraryItem> ordered = switch (order) {
      LibraryOrder.recent => items,
      LibraryOrder.alphabetical => List<LibraryItem>.of(
        items,
      )..sort(_compareAlphabetical),
    };
    return reversed ? ordered.reversed.toList(growable: false) : ordered;
  }
}

int _compareAlphabetical(LibraryItem a, LibraryItem b) {
  final String titleA = _titleOf(a);
  final String titleB = _titleOf(b);
  final int keyCompare = titleKey(titleA).compareTo(titleKey(titleB));
  if (keyCompare != 0) return keyCompare;
  final int titleCompare = titleA.compareTo(titleB);
  if (titleCompare != 0) return titleCompare;
  return _tieBreakId(a).compareTo(_tieBreakId(b));
}

String _titleOf(LibraryItem item) => switch (item) {
  LibraryEntryItem(:final Entry entry) => entry.title,
  LibraryGroupItem(:final String label) => label,
};

int _tieBreakId(LibraryItem item) => switch (item) {
  LibraryEntryItem(:final Entry entry) => entry.malId,
  LibraryGroupItem(:final int key) => key,
};
