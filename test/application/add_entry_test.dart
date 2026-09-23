import 'package:anihub/application/usecases/usecases.dart';
import 'package:anihub/domain/entities/catalog_anime.dart';
import 'package:anihub/domain/entities/entry.dart';
import 'package:anihub/domain/errors/duplicate_entry_exception.dart';
import 'package:anihub/domain/values/watch_status.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/in_memory_entry_repository.dart';

void main() {
  late InMemoryEntryRepository repository;
  late AddEntry addEntry;

  setUp(() {
    repository = InMemoryEntryRepository();
    addEntry = AddEntry(repository);
  });

  tearDown(() => repository.dispose());

  const CatalogAnime frieren = CatalogAnime(
    malId: 52991,
    title: 'Sousou no Frieren',
    coverUrl: 'https://example.test/frieren.jpg',
    totalEpisodes: 28,
    seasonYear: 2023,
  );

  test('creates the entry as planned by default', () async {
    final Entry created = await addEntry(frieren);

    expect(created.id, isNotNull);
    expect(created.malId, 52991);
    expect(created.title, 'Sousou no Frieren');
    expect(created.coverUrl, 'https://example.test/frieren.jpg');
    expect(created.totalEpisodes, 28);
    expect(created.status, WatchStatus.planned);

    expect(await repository.findAll(), hasLength(1));
  });

  test(
    'throws DuplicateEntryException for an anime already in the library',
    () async {
      await addEntry(frieren);

      await expectLater(
        addEntry(frieren),
        throwsA(
          isA<DuplicateEntryException>().having(
            (DuplicateEntryException e) => e.malId,
            'malId',
            52991,
          ),
        ),
      );

      expect(await repository.findAll(), hasLength(1));
    },
  );

  test('creates the entry with the given status', () async {
    final Entry created = await addEntry(frieren, status: WatchStatus.watching);

    expect(created.status, WatchStatus.watching);
    expect((await repository.findAll()).single.status, WatchStatus.watching);
  });

  test('creates the entry as a favorite when requested', () async {
    final Entry created = await addEntry(
      frieren,
      status: WatchStatus.completed,
      isFavorite: true,
    );

    expect(created.isFavorite, isTrue);
    expect((await repository.findAll()).single.isFavorite, isTrue);
  });

  for (final WatchStatus status in <WatchStatus>[
    WatchStatus.watching,
    WatchStatus.planned,
  ]) {
    test('stores a favorite added as ${status.wire} as completed', () async {
      final Entry created = await addEntry(
        frieren,
        status: status,
        isFavorite: true,
      );

      expect(created.status, WatchStatus.completed);
      expect(created.isFavorite, isTrue);
      final Entry stored = (await repository.findAll()).single;
      expect(stored.status, WatchStatus.completed);
      expect(stored.isFavorite, isTrue);
    });
  }

  test('keeps totalEpisodes null for airing series', () async {
    const CatalogAnime onePiece = CatalogAnime(
      malId: 21,
      title: 'One Piece',
      isAiring: true,
    );

    final Entry created = await addEntry(onePiece);

    expect(created.totalEpisodes, isNull);
  });
}
