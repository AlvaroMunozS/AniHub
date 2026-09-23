import 'package:anihub/application/usecases/usecases.dart';
import 'package:anihub/domain/entities/entry.dart';
import 'package:anihub/domain/values/watch_status.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/in_memory_entry_repository.dart';

void main() {
  late InMemoryEntryRepository repository;
  late SetFavorite setFavorite;

  setUp(() {
    repository = InMemoryEntryRepository();
    setFavorite = SetFavorite(repository);
  });

  tearDown(() => repository.dispose());

  Future<Entry> seed(WatchStatus status, {bool isFavorite = false}) {
    return repository.save(
      Entry(
        malId: 5114,
        title: 'Fullmetal Alchemist: Brotherhood',
        status: status,
        totalEpisodes: 64,
        updatedAt: DateTime(2024),
        isFavorite: isFavorite,
      ),
    );
  }

  test('favorites a completed entry without changing its status', () async {
    final Entry entry = await seed(WatchStatus.completed);

    final Entry result = await setFavorite(entry, isFavorite: true);

    expect(result.isFavorite, isTrue);
    expect(result.status, WatchStatus.completed);
    expect((await repository.findAll()).single.isFavorite, isTrue);
  });

  for (final WatchStatus status in <WatchStatus>[
    WatchStatus.watching,
    WatchStatus.planned,
  ]) {
    test('completes a ${status.wire} entry when favoriting it', () async {
      final Entry entry = await seed(status);

      final Entry result = await setFavorite(entry, isFavorite: true);

      expect(result.isFavorite, isTrue);
      expect(result.status, WatchStatus.completed);
      final Entry stored = (await repository.findAll()).single;
      expect(stored.isFavorite, isTrue);
      expect(stored.status, WatchStatus.completed);
    });
  }

  test('unfavorites an entry without changing its status', () async {
    final Entry entry = await seed(WatchStatus.completed, isFavorite: true);

    final Entry result = await setFavorite(entry, isFavorite: false);

    expect(result.isFavorite, isFalse);
    expect(result.status, WatchStatus.completed);
    expect((await repository.findAll()).single.isFavorite, isFalse);
  });

  for (final bool isFavorite in <bool>[true, false]) {
    test('gives the same result when setting isFavorite to $isFavorite '
        'twice', () async {
      final Entry entry = await seed(WatchStatus.watching);

      final Entry first = await setFavorite(entry, isFavorite: isFavorite);
      final Entry second = await setFavorite(first, isFavorite: isFavorite);

      expect(second.copyWith(updatedAt: first.updatedAt), first);
      expect(await repository.findAll(), hasLength(1));
    });
  }
}
