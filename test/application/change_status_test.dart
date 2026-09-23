import 'package:anihub/application/usecases/usecases.dart';
import 'package:anihub/domain/entities/entry.dart';
import 'package:anihub/domain/values/watch_status.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/in_memory_entry_repository.dart';

void main() {
  late InMemoryEntryRepository repository;
  late ChangeStatus changeStatus;

  setUp(() {
    repository = InMemoryEntryRepository();
    changeStatus = ChangeStatus(repository);
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

  test('saves the new status', () async {
    final Entry entry = await seed(WatchStatus.watching);

    final Entry result = await changeStatus(entry, WatchStatus.planned);

    expect(result.status, WatchStatus.planned);
    expect((await repository.findAll()).single.status, WatchStatus.planned);
  });

  test('does not favorite an entry when completing it', () async {
    final Entry entry = await seed(WatchStatus.watching);

    final Entry result = await changeStatus(entry, WatchStatus.completed);

    expect(result.status, WatchStatus.completed);
    expect(result.isFavorite, isFalse);
  });

  test('keeps the favorite of an entry that stays completed', () async {
    final Entry entry = await seed(WatchStatus.completed, isFavorite: true);

    final Entry result = await changeStatus(entry, WatchStatus.completed);

    expect(result.isFavorite, isTrue);
  });

  for (final WatchStatus status in <WatchStatus>[
    WatchStatus.watching,
    WatchStatus.planned,
  ]) {
    test(
      'clears the favorite when a favorite moves to ${status.wire}',
      () async {
        final Entry entry = await seed(WatchStatus.completed, isFavorite: true);

        final Entry result = await changeStatus(entry, status);

        expect(result.status, status);
        expect(result.isFavorite, isFalse);
        expect((await repository.findAll()).single.isFavorite, isFalse);
      },
    );
  }
}
