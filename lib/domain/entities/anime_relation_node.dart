import '../support/list_equality.dart';
import '../values/relation_kind.dart';
import '../values/release_date.dart';
import 'anime_relation.dart';

/// An anime together with its direct relations.
///
/// Carries the anime's own release data, not just its edges, because that is
/// what orders the members of a franchise group.
class AnimeRelationNode {
  const AnimeRelationNode({
    required this.malId,
    required this.title,
    this.coverUrl,
    this.seasonYear,
    this.startDate,
    this.relations = const <AnimeRelation>[],
  });

  final int malId;
  final String title;
  final String? coverUrl;
  final int? seasonYear;
  final ReleaseDate? startDate;

  /// Depth-1 relations to other anime, including [RelationKind.character]
  /// and [RelationKind.other].
  ///
  /// Whether an edge groups a franchise is decided by
  /// [RelationKind.groupsFranchise].
  final List<AnimeRelation> relations;

  @override
  bool operator ==(Object other) =>
      other is AnimeRelationNode &&
      other.malId == malId &&
      other.title == title &&
      other.coverUrl == coverUrl &&
      other.seasonYear == seasonYear &&
      other.startDate == startDate &&
      sameElements(other.relations, relations);

  @override
  int get hashCode => Object.hash(
    malId,
    title,
    coverUrl,
    seasonYear,
    startDate,
    Object.hashAll(relations),
  );

  @override
  String toString() =>
      'AnimeRelationNode($malId, $title, ${relations.length} relations)';
}
