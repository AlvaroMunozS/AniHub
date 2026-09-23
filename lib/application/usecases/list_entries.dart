import '../../domain/entities/entry.dart';
import '../../domain/ports/entry_repository.dart';

/// Watches the library, as emitted by [EntryRepository.watchAll].
class ListEntries {
  const ListEntries(this._repository);

  final EntryRepository _repository;

  Stream<List<Entry>> call() => _repository.watchAll();
}
