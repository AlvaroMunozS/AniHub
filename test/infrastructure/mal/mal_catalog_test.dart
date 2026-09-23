import 'package:anihub/domain/entities/catalog_anime.dart';
import 'package:anihub/domain/errors/catalog_exception.dart';
import 'package:anihub/domain/values/anime_season.dart';
import 'package:anihub/infrastructure/mal/mal_catalog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'fake_mal_api.dart';

const Map<String, Object?> _fullNode = <String, Object?>{
  'id': 5114,
  'title': 'Hagane no Renkinjutsushi: Fullmetal Alchemist',
  'main_picture': <String, Object?>{
    'medium': 'https://cdn.myanimelist.net/images/anime/1208/94745.jpg',
    'large': 'https://cdn.myanimelist.net/images/anime/1208/94745l.jpg',
  },
  'alternative_titles': <String, Object?>{
    'en': 'Fullmetal Alchemist: Brotherhood',
  },
  'start_date': '2009-04-05',
  'start_season': <String, Object?>{'year': 2009, 'season': 'spring'},
  'synopsis': '  Two brothers search for the Philosopher\'s Stone.\n',
  'num_episodes': 64,
  'status': 'finished_airing',
  'genres': <Object?>[
    <String, Object?>{'id': 1, 'name': 'Action'},
    <String, Object?>{'id': 2, 'name': 'Adventure'},
  ],
  'studios': <Object?>[
    <String, Object?>{'id': 4, 'name': 'Bones'},
    <String, Object?>{'id': 5, 'name': 'Aniplex'},
  ],
};

http.Response _page(List<Map<String, Object?>> nodes) =>
    jsonResponse(<String, Object?>{
      'data': <Object?>[
        for (final Map<String, Object?> node in nodes)
          <String, Object?>{'node': node},
      ],
    });

void main() {
  group('byId', () {
    test('maps every detail field', () async {
      final FakeMalApi server = FakeMalApi.sequence(<http.Response>[
        jsonResponse(_fullNode),
      ]);

      final CatalogAnime anime = await MalCatalog(server.client()).byId(5114);

      expect(
        anime,
        const CatalogAnime(
          malId: 5114,
          title: 'Fullmetal Alchemist: Brotherhood',
          coverUrl: 'https://cdn.myanimelist.net/images/anime/1208/94745l.jpg',
          totalEpisodes: 64,
          seasonYear: 2009,
          season: AnimeSeason.spring,
          description: "Two brothers search for the Philosopher's Stone.",
          genres: <String>['Action', 'Adventure'],
          studioName: 'Bones',
        ),
      );
      expect(server.requests.single.path, '/v2/anime/5114');
      expect(
        server.requests.single.queryParameters['fields'],
        allOf(contains('synopsis'), contains('genres'), contains('studios')),
      );
    });

    test('falls back to the main title, the medium cover and the start '
        'date year', () async {
      final FakeMalApi server = FakeMalApi.sequence(<http.Response>[
        jsonResponse(<String, Object?>{
          'id': 7,
          'title': 'Sousou no Frieren',
          'alternative_titles': <String, Object?>{'en': '  '},
          'main_picture': <String, Object?>{'medium': 'https://example/m.jpg'},
          'start_date': '2027-10',
        }),
      ]);

      final CatalogAnime anime = await MalCatalog(server.client()).byId(7);

      expect(anime.title, 'Sousou no Frieren');
      expect(anime.coverUrl, 'https://example/m.jpg');
      expect(anime.seasonYear, 2027);
      expect(anime.season, isNull);
    });

    test('treats a zero episode count as unknown', () async {
      final FakeMalApi server = FakeMalApi.sequence(<http.Response>[
        jsonResponse(<String, Object?>{
          'id': 21,
          'title': 'One Piece',
          'num_episodes': 0,
          'status': 'currently_airing',
        }),
      ]);

      final CatalogAnime anime = await MalCatalog(server.client()).byId(21);

      expect(anime.totalEpisodes, isNull);
      expect(anime.isAiring, isTrue);
    });

    test('ignores optional fields of an unexpected type', () async {
      final FakeMalApi server = FakeMalApi.sequence(<http.Response>[
        jsonResponse(<String, Object?>{
          'id': 1,
          'title': 'Cowboy Bebop',
          'num_episodes': '26',
          'start_season': 1998,
          'start_date': 'soon',
          'genres': <Object?>[
            'Action',
            <String, Object?>{'name': 'Drama'},
          ],
          'studios': <Object?>[],
          'synopsis': '',
        }),
      ]);

      final CatalogAnime anime = await MalCatalog(server.client()).byId(1);

      expect(
        anime,
        const CatalogAnime(
          malId: 1,
          title: 'Cowboy Bebop',
          genres: <String>['Drama'],
        ),
      );
    });

    test('throws a not found error for an unknown id', () async {
      final FakeMalApi server = FakeMalApi.sequence(<http.Response>[
        jsonResponse(<String, Object?>{'error': 'not_found'}, 404),
      ]);

      await expectLater(
        MalCatalog(server.client()).byId(999),
        throwsA(
          isA<CatalogNotFoundException>().having(
            (CatalogNotFoundException e) => e.malId,
            'malId',
            999,
          ),
        ),
      );
    });

    test('throws a response error for a node without id or title', () async {
      for (final Map<String, Object?> node in <Map<String, Object?>>[
        <String, Object?>{'title': 'No id'},
        <String, Object?>{'id': 3},
      ]) {
        final FakeMalApi server = FakeMalApi.sequence(<http.Response>[
          jsonResponse(node),
        ]);

        await expectLater(
          MalCatalog(server.client()).byId(3),
          throwsA(isA<CatalogResponseException>()),
          reason: '$node',
        );
      }
    });
  });

  group('search', () {
    test('sends the trimmed query and maps each result', () async {
      final FakeMalApi server = FakeMalApi.sequence(<http.Response>[
        _page(<Map<String, Object?>>[
          _fullNode,
          <String, Object?>{'id': 1, 'title': 'Cowboy Bebop'},
        ]),
      ]);

      final List<CatalogAnime> results = await MalCatalog(server.client())
          .search('  fullmetal ', limit: 5);

      expect(results.map((CatalogAnime a) => a.malId), <int>[5114, 1]);
      expect(results.first.title, 'Fullmetal Alchemist: Brotherhood');
      final Uri request = server.requests.single;
      expect(request.path, '/v2/anime');
      expect(request.queryParameters['q'], 'fullmetal');
      expect(request.queryParameters['limit'], '5');
    });

    test('caps the page size at 100', () async {
      final FakeMalApi server = FakeMalApi.sequence(<http.Response>[
        _page(const <Map<String, Object?>>[]),
      ]);

      await MalCatalog(server.client()).search('naruto', limit: 500);

      expect(server.requests.single.queryParameters['limit'], '100');
    });

    test('returns nothing without a request for queries shorter than three '
        'characters', () async {
      final FakeMalApi server = FakeMalApi.sequence(const <http.Response>[]);
      final MalCatalog catalog = MalCatalog(server.client());

      expect(await catalog.search(''), isEmpty);
      expect(await catalog.search(' ab '), isEmpty);
      expect(server.requests, isEmpty);
    });

    test('answers a repeated query from memory, ignoring case and '
        'surrounding spaces', () async {
      final FakeMalApi server = FakeMalApi.sequence(<http.Response>[
        _page(<Map<String, Object?>>[_fullNode]),
      ]);
      final MalCatalog catalog = MalCatalog(server.client());

      final List<CatalogAnime> first = await catalog.search('Frieren');
      final List<CatalogAnime> second = await catalog.search(' frieren ');

      expect(second, same(first));
      expect(server.requests, hasLength(1));
    });

    test('throws a response error for a malformed page', () async {
      final FakeMalApi server = FakeMalApi.sequence(<http.Response>[
        jsonResponse(<String, Object?>{'data': 'nope'}),
      ]);

      await expectLater(
        MalCatalog(server.client()).search('frieren'),
        throwsA(isA<CatalogResponseException>()),
      );
    });

    test('skips results without a node, an id or a title', () async {
      final FakeMalApi server = FakeMalApi.sequence(<http.Response>[
        jsonResponse(<String, Object?>{
          'data': <Object?>[
            <String, Object?>{'node': 'nope'},
            <String, Object?>{
              'node': <String, Object?>{'title': 'No id'},
            },
            <String, Object?>{
              'node': <String, Object?>{'id': 2},
            },
            <String, Object?>{
              'node': <String, Object?>{'id': 1, 'title': 'Cowboy Bebop'},
            },
          ],
        }),
      ]);

      final List<CatalogAnime> results = await MalCatalog(server.client())
          .search('bebop');

      expect(results.map((CatalogAnime a) => a.malId), <int>[1]);
    });
  });
}
