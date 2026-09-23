import 'package:anihub/domain/entities/entry.dart';
import 'package:anihub/domain/values/watch_status.dart';
import 'package:flutter_test/flutter_test.dart';

import 'entry_repository_contract.dart';
import 'in_memory_entry_repository.dart';

void main() {
  entryRepositoryContract((DateTime Function() now) async {
    final InMemoryEntryRepository repo = InMemoryEntryRepository(now: now);
    addTearDown(repo.dispose);
    return repo;
  }, constraintError: isStateError);

  test('starts with the seed entries, keeping their ids', () async {
    final Entry withId = Entry(
      id: 'seeded',
      malId: 1,
      title: 'Frieren',
      status: WatchStatus.completed,
      updatedAt: DateTime.utc(2024, 2),
    );
    final Entry withoutId = Entry(
      malId: 2,
      title: 'Mushishi',
      status: WatchStatus.planned,
      updatedAt: DateTime.utc(2024),
    );
    final InMemoryEntryRepository repo = InMemoryEntryRepository(
      seed: <Entry>[withId, withoutId],
    );
    addTearDown(repo.dispose);

    final List<Entry> all = await repo.findAll();

    expect(all.first, withId);
    expect(all.last, withoutId.copyWith(id: all.last.id));
    expect(all.last.id, isNotNull);
  });
}
