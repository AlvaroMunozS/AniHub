import 'dart:async';

import 'package:anihub/domain/entities/entry.dart';
import 'package:anihub/domain/errors/duplicate_entry_exception.dart';
import 'package:anihub/domain/ports/entry_repository.dart';

/// [EntryRepository] held in memory that behaves like the SQLite one.
///
/// Like the database, [save] throws a [DuplicateEntryException] for a
/// duplicate `malId`; other writes it would reject, such as a [save] with an
/// unknown id, throw a [StateError].
class InMemoryEntryRepository implements EntryRepository {
  InMemoryEntryRepository({
    List<Entry> seed = const <Entry>[],
    this.now = DateTime.now,
  }) {
    for (final Entry entry in seed) {
      final String id = entry.id ?? _newId();
      _entries[id] = entry.copyWith(id: id);
    }
  }

  /// Source of the timestamp that [save] stamps on entries.
  final DateTime Function() now;

  Map<String, Entry> _entries = <String, Entry>{};
  final StreamController<List<Entry>> _changes =
      StreamController<List<Entry>>.broadcast();
  int _lastId = 0;

  String _newId() => 'mem-${++_lastId}';

  List<Entry> _snapshot() => List<Entry>.unmodifiable(
    _entries.values.toList()
      ..sort((Entry a, Entry b) => b.updatedAt.compareTo(a.updatedAt)),
  );

  void _notifyChange() => _changes.add(_snapshot());

  @override
  Future<List<Entry>> findAll() async => _snapshot();

  @override
  Future<Entry> save(Entry entry) async {
    final String? existingId = entry.id;
    if (existingId != null && !_entries.containsKey(existingId)) {
      throw StateError('No entry with id $existingId');
    }
    if (_entries.values.any(
      (Entry other) => other.malId == entry.malId && other.id != existingId,
    )) {
      throw DuplicateEntryException(entry.malId);
    }

    final String id = existingId ?? _newId();
    final Entry saved = entry.copyWith(id: id, updatedAt: now().toUtc());
    _entries[id] = saved;
    _notifyChange();
    return saved;
  }

  @override
  Future<void> delete(String id) async {
    _entries.remove(id);
    _notifyChange();
  }

  @override
  Stream<List<Entry>> watchAll() {
    return Stream<List<Entry>>.multi((MultiStreamController<List<Entry>> out) {
      out.add(_snapshot());
      final StreamSubscription<List<Entry>> changes = _changes.stream.listen(
        out.add,
        onError: out.addError,
        onDone: out.close,
      );
      out.onCancel = changes.cancel;
    });
  }

  @override
  Future<void> upsertAll(List<Entry> entries) async {
    if (entries.isEmpty) return;

    // Applied to a copy so that a rejected entry leaves the library untouched,
    // like the database transaction.
    final Map<String, Entry> next = Map<String, Entry>.of(_entries);
    for (final Entry entry in entries) {
      final String? matchId = next.values
          .where((Entry other) => other.malId == entry.malId)
          .firstOrNull
          ?.id;
      final String id = matchId ?? entry.id ?? _newId();
      if (matchId == null && next.containsKey(id)) {
        throw StateError('Entry id $id is already taken');
      }
      next[id] = entry.copyWith(id: id, updatedAt: entry.updatedAt.toUtc());
    }
    _entries = next;
    _notifyChange();
  }

  Future<void> dispose() => _changes.close();
}
