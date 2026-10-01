import 'package:anihub/application/usecases/usecases.dart';
import 'package:anihub/domain/entities/catalog_anime.dart';
import 'package:flutter_test/flutter_test.dart';

CatalogAnime _anime(int id, String title, [int? members]) =>
    CatalogAnime(malId: id, title: title, memberCount: members);

List<String> _titles(List<CatalogAnime> anime) => <String>[
  for (final CatalogAnime item in anime) item.title,
];

void main() {
  const RankSeason rank = RankSeason();

  test('orders by members, then by title, unknown counts last', () {
    final List<CatalogAnime> ranked = rank(<CatalogAnime>[
      _anime(1, 'Unknown'),
      _anime(2, 'Zeta', 6000),
      _anime(3, 'Re:Zero', 334883),
      _anime(4, 'Beta', 6000),
    ], upcoming: false);

    expect(_titles(ranked), <String>['Re:Zero', 'Beta', 'Zeta', 'Unknown']);
  });

  test('leaves out anime in too few lists in a season already aired', () {
    final List<CatalogAnime> ranked = rank(<CatalogAnime>[
      _anime(1, 'Niche', ScheduleAiring.minMembers - 1),
      _anime(2, 'Known', ScheduleAiring.minMembers),
    ], upcoming: false);

    expect(_titles(ranked), <String>['Known']);
  });

  test('accepts fewer lists for the next season', () {
    final List<CatalogAnime> ranked = rank(<CatalogAnime>[
      _anime(1, 'Niche', RankSeason.upcomingMinMembers - 1),
      _anime(2, 'Expected', RankSeason.upcomingMinMembers),
      _anime(3, 'Unknown'),
    ], upcoming: true);

    expect(_titles(ranked), <String>['Expected', 'Unknown']);
  });
}
