/// Thrown when adding an anime that is already in the library.
class DuplicateEntryException implements Exception {
  const DuplicateEntryException(this.malId);

  final int malId;

  @override
  String toString() =>
      'DuplicateEntryException: anime $malId is already in the library';
}
