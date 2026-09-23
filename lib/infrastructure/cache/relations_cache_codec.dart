import 'dart:convert';

import '../../domain/entities/anime_relation.dart';
import '../../domain/entities/anime_relation_node.dart';
import '../../domain/values/relation_kind.dart';
import '../../domain/values/release_date.dart';

// Bump on any incompatible change to the JSON shape: caches written with
// another version are discarded.
const int _formatVersion = 1;

/// An [AnimeRelationNode] stamped with the time it was cached.
class CachedRelationNode {
  const CachedRelationNode({required this.savedAt, required this.node});

  final DateTime savedAt;
  final AnimeRelationNode node;

  @override
  bool operator ==(Object other) =>
      other is CachedRelationNode &&
      other.savedAt == savedAt &&
      other.node == node;

  @override
  int get hashCode => Object.hash(savedAt, node);

  @override
  String toString() => 'CachedRelationNode($savedAt, $node)';
}

/// Encodes the relation cache as JSON readable by [decodeRelationsCache].
String encodeRelationsCache(Map<int, CachedRelationNode> nodes) {
  return jsonEncode(<String, Object?>{
    'v': _formatVersion,
    'nodes': <String, Object?>{
      for (final MapEntry<int, CachedRelationNode>(:int key, :value)
          in nodes.entries)
        '$key': <String, Object?>{
          'savedAt': value.savedAt.toIso8601String(),
          'node': _nodeToJson(value.node),
        },
    },
  });
}

/// Decodes a cache written by [encodeRelationsCache], or returns null if
/// there is none.
///
/// Unreadable JSON, an unexpected root shape or a different format version
/// yield null. A node without a valid `savedAt`, `malId` or `title` is
/// skipped, and so is a relation without a `malId`, a `title` or a known
/// `kind`. Optional fields of the wrong type are read as absent.
Map<int, CachedRelationNode>? decodeRelationsCache(String? json) {
  if (json == null || json.isEmpty) return null;

  final Object? root;
  try {
    root = jsonDecode(json);
  } on FormatException {
    return null;
  }

  if (root case {
    'v': _formatVersion,
    'nodes': final Map<String, Object?> nodes,
  }) {
    return <int, CachedRelationNode>{
      for (final MapEntry<String, Object?>(:String key, :value)
          in nodes.entries)
        if ((int.tryParse(key), _cachedNodeFromJson(value)) case (
          final int id,
          final CachedRelationNode cached,
        ))
          id: cached,
    };
  }
  return null;
}

Map<String, Object?> _nodeToJson(AnimeRelationNode node) {
  final ReleaseDate? startDate = node.startDate;
  return <String, Object?>{
    'malId': node.malId,
    'title': node.title,
    'coverUrl': node.coverUrl,
    'seasonYear': node.seasonYear,
    'startDate': startDate == null
        ? null
        : <String, Object?>{
            'year': startDate.year,
            'month': startDate.month,
            'day': startDate.day,
          },
    'relations': <Object?>[
      for (final AnimeRelation relation in node.relations)
        <String, Object?>{
          'malId': relation.malId,
          'kind': relation.kind.wire,
          'title': relation.title,
          'coverUrl': relation.coverUrl,
          'seasonYear': relation.seasonYear,
        },
    ],
  };
}

CachedRelationNode? _cachedNodeFromJson(Object? json) {
  if (json case {
    'savedAt': final String rawSavedAt,
    'node':
        {'malId': final int malId, 'title': final String title} &&
        final Map<String, Object?> node,
  }) {
    if (DateTime.tryParse(rawSavedAt) case final DateTime savedAt) {
      return CachedRelationNode(
        savedAt: savedAt,
        node: AnimeRelationNode(
          malId: malId,
          title: title,
          coverUrl: _optional<String>(node['coverUrl']),
          seasonYear: _optional<int>(node['seasonYear']),
          startDate: switch (node['startDate']) {
            final Map<String, Object?> date => ReleaseDate(
              year: _optional<int>(date['year']),
              month: _optional<int>(date['month']),
              day: _optional<int>(date['day']),
            ),
            _ => null,
          },
          relations: List<AnimeRelation>.unmodifiable(<AnimeRelation>[
            if (node['relations'] case final List<Object?> relations)
              for (final Object? relation in relations)
                if (_relationFromJson(relation) case final AnimeRelation parsed)
                  parsed,
          ]),
        ),
      );
    }
  }
  return null;
}

AnimeRelation? _relationFromJson(Object? json) {
  if (json case {
    'malId': final int malId,
    'kind': final String rawKind,
    'title': final String title,
  }) {
    if (RelationKind.tryFromWire(rawKind) case final RelationKind kind) {
      return AnimeRelation(
        malId: malId,
        kind: kind,
        title: title,
        coverUrl: _optional<String>(json['coverUrl']),
        seasonYear: _optional<int>(json['seasonYear']),
      );
    }
  }
  return null;
}

T? _optional<T extends Object>(Object? value) => value is T ? value : null;
