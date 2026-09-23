import 'dart:async';

import 'package:anihub/application/usecases/usecases.dart';
import 'package:anihub/domain/entities/entry.dart';
import 'package:anihub/domain/values/watch_status.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/in_memory_entry_repository.dart';

void main() {
  late InMemoryEntryRepository repository;
  late ListEntries listEntries;

  setUp(() {
    repository = InMemoryEntryRepository();
    listEntries = ListEntries(repository);
  });

  tearDown(() => repository.dispose());

  Entry sample({required int malId, required String title}) {
    return Entry(
      malId: malId,
      title: title,
      status: WatchStatus.planned,
      updatedAt: DateTime(2024),
    );
  }

  test('watches the library through the repository', () async {
    final List<List<Entry>> seen = <List<Entry>>[];
    final StreamSubscription<List<Entry>> sub = listEntries().listen(seen.add);
    addTearDown(sub.cancel);

    await pumpEventQueue();
    expect(seen, hasLength(1));
    expect(seen.single, isEmpty);

    await repository.save(sample(malId: 21, title: 'One Piece'));
    await pumpEventQueue();

    expect(seen, hasLength(2));
    expect(seen.last, hasLength(1));
  });
}
