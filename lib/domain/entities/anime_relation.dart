import '../values/relation_kind.dart';

/// A related anime and how it relates to the anime that lists it.
class AnimeRelation {
  const AnimeRelation({
    required this.malId,
    required this.kind,
    required this.title,
    this.coverUrl,
    this.seasonYear,
  });

  final int malId;
  final RelationKind kind;
  final String title;
  final String? coverUrl;
  final int? seasonYear;

  @override
  bool operator ==(Object other) =>
      other is AnimeRelation &&
      other.malId == malId &&
      other.kind == kind &&
      other.title == title &&
      other.coverUrl == coverUrl &&
      other.seasonYear == seasonYear;

  @override
  int get hashCode => Object.hash(malId, kind, title, coverUrl, seasonYear);

  @override
  String toString() => 'AnimeRelation(${kind.wire}, $malId, $title)';
}
