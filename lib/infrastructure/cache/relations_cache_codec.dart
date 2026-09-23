import 'dart:convert';

import '../../domain/entities/anime_relation.dart';
import '../../domain/entities/anime_relation_node.dart';
import '../../domain/values/relation_kind.dart';
import '../../domain/values/release_date.dart';

// Version of the snapshot format read by [decodeRelationsCache]; snapshots
// with another version are discarded.
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

/// Encodes [node] as the JSON read by [decodeRelationNode].
String encodeRelationNode(AnimeRelationNode node) =>
    jsonEncode(_nodeToJson(node));

/// Decodes a node written by [encodeRelationNode], or returns null if [json]
/// is unreadable or lacks a valid `malId` or `title`.
///
/// A relation without a `malId`, a `title` or a known `kind` is skipped.
/// Optional fields of the wrong type are read as absent.
AnimeRelationNode? decodeRelationNode(String json) {
  try {
    return _nodeFromJson(jsonDecode(json));
  } on FormatException {
    return null;
  }
}

/// Decodes a whole relation graph snapshot, the format of the preferences
/// key that `SqfliteRelationsStore` migrates.
///
/// Unreadable JSON, an unexpected root shape or a different format version
/// yield null. A node without a valid `savedAt`, `malId` or `title` is
/// skipped, and so is a relation without a `malId`, a `title` or a known
/// `kind`. Optional fields of the wrong type are read as absent.
Map<int, CachedRelationNode>? decodeRelationsCache(String json) {
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
    'node': final Object? raw,
  }) {
    if ((DateTime.tryParse(rawSavedAt), _nodeFromJson(raw)) case (
      final DateTime savedAt,
      final AnimeRelationNode node,
    )) {
      return CachedRelationNode(savedAt: savedAt, node: node);
    }
  }
  return null;
}

AnimeRelationNode? _nodeFromJson(Object? json) {
  if (json
      case {'malId': final int malId, 'title': final String title} &&
          final Map<String, Object?> node) {
    return AnimeRelationNode(
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
    );
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
