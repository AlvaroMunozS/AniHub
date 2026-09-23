/// Type of relation between two anime, mirroring MyAnimeList's
/// `relation_type`.
///
/// Covers every relation type, not only those that group a franchise, so the
/// detail screen can list all relations without another request.
/// [groupsFranchise] is the single place that decides grouping.
enum RelationKind {
  sequel('sequel'),
  prequel('prequel'),
  sideStory('side_story'),
  parentStory('parent_story'),
  spinOff('spin_off'),
  alternativeVersion('alternative_version'),
  alternativeSetting('alternative_setting'),
  summary('summary'),
  fullStory('full_story'),
  character('character'),
  other('other');

  const RelationKind(this.wire);

  /// Value as returned by MyAnimeList.
  final String wire;

  /// Parses a relation type, or returns null if it is unknown.
  ///
  /// Never throws: MyAnimeList may add relation types at any time, and an
  /// edge that cannot be parsed is ignored rather than breaking grouping.
  static RelationKind? tryFromWire(String? value) {
    if (value == null) return null;
    for (final kind in RelationKind.values) {
      if (kind.wire == value) return kind;
    }
    return null;
  }

  /// Whether an edge of this kind puts both anime in the same franchise group.
  bool get groupsFranchise => this != character && this != other;
}
