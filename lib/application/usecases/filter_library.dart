import '../../domain/entities/entry.dart';
import 'filter_mode.dart';
import 'title_key.dart';

/// Filters the library by title, favorite flag and started franchise.
///
/// Must run before `GroupLibrary`: filtering afterwards would keep the
/// non-matching members of a group with a single match.
class FilterLibrary {
  const FilterLibrary();

  /// Returns the entries whose title contains [query], whose favorite flag
  /// passes [favorites] and whose franchise passes [notStarted].
  ///
  /// An entry is not started when its MyAnimeList id is missing from
  /// [started], as `FindStartedEntries` returns it.
  ///
  /// Matching ignores case and diacritics (see [titleKey]), so "kokaku"
  /// matches "Kōkaku". A blank [query] matches every title.
  List<Entry> call(
    List<Entry> entries, {
    String query = '',
    FilterMode favorites = FilterMode.any,
    FilterMode notStarted = FilterMode.any,
    Set<int> started = const <int>{},
  }) {
    final String trimmed = query.trim();
    if (trimmed.isEmpty &&
        favorites == FilterMode.any &&
        notStarted == FilterMode.any) {
      return entries;
    }
    final String needle = titleKey(trimmed);
    return entries
        .where((Entry entry) {
          if (!favorites.matches(entry.isFavorite)) return false;
          if (!notStarted.matches(!started.contains(entry.malId))) {
            return false;
          }
          if (needle.isEmpty) return true;
          return titleKey(entry.title).contains(needle);
        })
        .toList(growable: false);
  }
}
