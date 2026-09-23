import 'package:anihub/domain/entities/catalog_anime.dart';
import 'package:anihub/domain/entities/entry.dart';
import 'package:anihub/domain/values/watch_status.dart';

/// A few real MyAnimeList titles. One Piece is airing and has no episode count.
const List<CatalogAnime> sampleCatalog = <CatalogAnime>[
  CatalogAnime(
    malId: 21,
    title: 'One Piece',
    seasonYear: 1999,
    isAiring: true,
    coverUrl: 'https://cdn.myanimelist.net/images/anime/1244/138851l.jpg',
  ),
  CatalogAnime(
    malId: 5114,
    title: 'Fullmetal Alchemist: Brotherhood',
    totalEpisodes: 64,
    seasonYear: 2009,
    coverUrl: 'https://cdn.myanimelist.net/images/anime/1208/94745l.jpg',
    description:
        'After a failed alchemy ritual, the Elric brothers search for the '
        "Philosopher's Stone to restore their bodies.",
    genres: <String>['Action', 'Adventure', 'Drama', 'Fantasy'],
    studioName: 'Bones',
  ),
  CatalogAnime(
    malId: 9253,
    title: 'Steins;Gate',
    totalEpisodes: 24,
    seasonYear: 2011,
    coverUrl: 'https://cdn.myanimelist.net/images/anime/1935/127974l.jpg',
  ),
  CatalogAnime(
    malId: 16498,
    title: 'Shingeki no Kyojin',
    totalEpisodes: 25,
    seasonYear: 2013,
    coverUrl: 'https://cdn.myanimelist.net/images/anime/10/47347l.webp',
  ),
  CatalogAnime(
    malId: 1,
    title: 'Cowboy Bebop',
    totalEpisodes: 26,
    seasonYear: 1998,
    coverUrl: 'https://cdn.myanimelist.net/images/anime/4/19644l.jpg',
  ),
  CatalogAnime(
    malId: 52991,
    title: 'Sousou no Frieren',
    totalEpisodes: 28,
    seasonYear: 2023,
    coverUrl: 'https://cdn.myanimelist.net/images/anime/1015/138006l.webp',
    description:
        'With the Demon King defeated, the elf mage Frieren outlives her '
        'human companions and sets out to understand them.',
    genres: <String>['Adventure', 'Drama', 'Fantasy'],
    studioName: 'Madhouse',
  ),
  CatalogAnime(
    malId: 30484,
    title: 'Steins;Gate 0',
    totalEpisodes: 23,
    seasonYear: 2018,
    coverUrl: 'https://cdn.myanimelist.net/images/anime/1375/93521l.jpg',
  ),
];

CatalogAnime _catalogById(int malId) =>
    sampleCatalog.firstWhere((a) => a.malId == malId);

/// Returns a library covering every status, timestamped relative to now.
///
/// Includes Steins;Gate and its sequel Steins;Gate 0, which form a franchise
/// group when their relations are known.
List<Entry> sampleEntries() {
  final DateTime now = DateTime.now();
  Entry from(
    int malId, {
    required WatchStatus status,
    required Duration ago,
    bool isFavorite = false,
  }) {
    final CatalogAnime meta = _catalogById(malId);
    return Entry(
      malId: meta.malId,
      title: meta.title,
      coverUrl: meta.coverUrl,
      totalEpisodes: meta.totalEpisodes,
      status: status,
      updatedAt: now.subtract(ago),
      isFavorite: isFavorite,
    );
  }

  return <Entry>[
    from(21, status: WatchStatus.watching, ago: const Duration(hours: 2)),

    from(
      9253,
      status: WatchStatus.completed,
      ago: const Duration(days: 3),
      isFavorite: true,
    ),
    from(5114, status: WatchStatus.watching, ago: const Duration(days: 1)),
    from(52991, status: WatchStatus.planned, ago: const Duration(days: 7)),
    from(16498, status: WatchStatus.completed, ago: const Duration(days: 10)),
    from(
      30484,
      status: WatchStatus.completed,
      ago: const Duration(days: 5),
      isFavorite: true,
    ),
  ];
}
