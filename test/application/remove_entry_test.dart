import 'package:anihub/application/usecases/usecases.dart';
import 'package:anihub/domain/entities/entry.dart';
import 'package:anihub/domain/values/watch_status.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/in_memory_entry_repository.dart';

void main() {
  late InMemoryEntryRepository repository;
  late RemoveEntry removeEntry;

  setUp(() {
    repository = InMemoryEntryRepository();
    removeEntry = RemoveEntry(repository);
  });

  tearDown(() => repository.dispose());

  test('removes the entry with the given id', () async {
    final Entry entry = await repository.save(
      Entry(
        malId: 21,
        title: 'One Piece',
        status: WatchStatus.watching,
        updatedAt: DateTime(2024),
      ),
    );

    await removeEntry(entry.id!);

    expect(await repository.findAll(), isEmpty);
  });
}
