import '../../domain/entities/entry.dart';
import 'title_key.dart';

/// Filters the library by title and favorite flag.
///
/// Must run before `GroupLibrary`: filtering afterwards would keep the
/// non-matching members of a group with a single match.
class FilterLibrary {
  const FilterLibrary();

  /// Returns the entries whose title contains [query] and, when
  /// [onlyFavorites] is set, that are favorites.
  ///
  /// Matching ignores case and diacritics (see [titleKey]), so "kokaku"
  /// matches "Kōkaku". A blank [query] matches every title.
  List<Entry> call(
    List<Entry> entries, {
    String query = '',
    bool onlyFavorites = false,
  }) {
    final String trimmed = query.trim();
    if (trimmed.isEmpty && !onlyFavorites) return entries;
    final String needle = titleKey(trimmed);
    return entries
        .where((Entry entry) {
          if (onlyFavorites && !entry.isFavorite) return false;
          if (needle.isEmpty) return true;
          return titleKey(entry.title).contains(needle);
        })
        .toList(growable: false);
  }
}
