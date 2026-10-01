import '../../domain/entities/catalog_anime.dart';
import 'title_key.dart';

/// Most followed first, then by title; unknown counts go last.
int compareRelevance(CatalogAnime a, CatalogAnime b) {
  final int membersCompare = (b.memberCount ?? -1).compareTo(
    a.memberCount ?? -1,
  );
  if (membersCompare != 0) return membersCompare;
  final int keyCompare = titleKey(a.title).compareTo(titleKey(b.title));
  if (keyCompare != 0) return keyCompare;
  return a.malId.compareTo(b.malId);
}
