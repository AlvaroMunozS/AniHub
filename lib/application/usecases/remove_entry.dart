import '../../domain/ports/entry_repository.dart';

/// Removes an entry from the library.
///
/// Removing an id that does not exist is a no-op, as guaranteed by
/// [EntryRepository.delete].
class RemoveEntry {
  const RemoveEntry(this._repository);

  final EntryRepository _repository;

  Future<void> call(String id) => _repository.delete(id);
}
