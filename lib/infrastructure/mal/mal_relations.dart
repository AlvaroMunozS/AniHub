import 'dart:math';

import '../../domain/entities/anime_relation.dart';
import '../../domain/entities/anime_relation_node.dart';
import '../../domain/ports/anime_relations.dart';
import '../../domain/values/relation_kind.dart';
import 'mal_client.dart';
import 'mal_mapping.dart';

/// [AnimeRelations] backed by the `related_anime` field of MyAnimeList.
///
/// MyAnimeList has no batch lookup, so each id costs one request. At most
/// [concurrency] requests run at a time. Results are not cached here; wrap it
/// in `CachingAnimeRelations` for that.
class MalRelations implements AnimeRelations {
  MalRelations(this._client, {this.concurrency = 4})
    : assert(concurrency > 0, 'concurrency must be positive');

  static const String _fields =
      'alternative_titles,start_season,start_date,'
      'related_anime{node{alternative_titles,start_season,start_date}}';

  final MalClient _client;

  final int concurrency;

  @override
  Future<Map<int, AnimeRelationNode>> forIds(Iterable<int> malIds) async {
    final Set<int> ids = malIds.toSet();
    final Map<int, AnimeRelationNode> resolved = <int, AnimeRelationNode>{};
    final Iterator<int> pending = ids.iterator;
    bool failed = false;

    Future<void> worker() async {
      while (!failed && pending.moveNext()) {
        final int id = pending.current;
        try {
          final Map<String, Object?>? body = await _client.get(
            'anime/$id',
            <String, String>{'fields': _fields},
          );
          if (body != null) resolved[id] = _toNode(body);
        } on Object {
          failed = true;
          rethrow;
        }
      }
    }

    await Future.wait(<Future<void>>[
      for (int i = 0; i < min(concurrency, ids.length); i++) worker(),
    ]);
    return resolved;
  }

  static AnimeRelationNode _toNode(Map<String, Object?> node) {
    final int id = parseId(node);
    return AnimeRelationNode(
      malId: id,
      title: requireTitle(node),
      coverUrl: parseCoverUrl(node),
      seasonYear: parseYear(node),
      startDate: parseStartDate(node),
      relations: List<AnimeRelation>.unmodifiable(<AnimeRelation>[
        if (node case {'related_anime': final List<Object?> edges})
          for (final Object? edge in edges)
            if (_toRelation(id, edge) case final AnimeRelation relation)
              relation,
      ]),
    );
  }

  // Drops self-references, unknown relation types and nodes without an id or
  // a title.
  static AnimeRelation? _toRelation(int rootId, Object? edge) {
    if (edge case {
      'relation_type': final String type,
      'node': final Map<String, Object?> node,
    }) {
      final RelationKind? kind = RelationKind.tryFromWire(type);
      final String? title = parseTitle(node);
      if (node case {'id': final int id}
          when id != rootId && kind != null && title != null) {
        return AnimeRelation(
          malId: id,
          kind: kind,
          title: title,
          coverUrl: parseCoverUrl(node),
          seasonYear: parseYear(node),
        );
      }
    }
    return null;
  }
}
