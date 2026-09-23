import 'dart:async';

import 'package:anihub/domain/entities/entry.dart';
import 'package:anihub/domain/ports/entry_repository.dart';

/// [EntryRepository] whose stream emits only on subscription and on
/// [emitCurrent], so optimistic changes can be observed before the stream
/// confirms them.
///
/// Writes can be held in flight with [saveGate] or made to fail with
/// [failSave] and [failDelete].
class ControllableRepository implements EntryRepository {
  ControllableRepository(this._entries);

  List<Entry> _entries;
  final StreamController<List<Entry>> _controller =
      StreamController<List<Entry>>.broadcast();

  bool failSave = false;
  bool failDelete = false;

  /// When set, `save` waits for it, keeping the write in flight.
  Completer<void>? saveGate;

  void emitCurrent() => _controller.add(List<Entry>.of(_entries));

  Future<void> dispose() => _controller.close();

  @override
  Stream<List<Entry>> watchAll() async* {
    yield List<Entry>.of(_entries);
    yield* _controller.stream;
  }

  @override
  Future<List<Entry>> findAll() async => List<Entry>.of(_entries);

  @override
  Future<Entry> save(Entry entry) async {
    await saveGate?.future;
    if (failSave) throw StateError('save failed');
    _entries = <Entry>[
      for (final Entry e in _entries)
        if (e.id == entry.id) entry else e,
    ];
    return entry;
  }

  @override
  Future<void> delete(String id) async {
    if (failDelete) throw StateError('delete failed');
    _entries = _entries.where((Entry e) => e.id != id).toList();
  }

  @override
  Future<void> upsertAll(List<Entry> entries) async {
    _entries = <Entry>[..._entries, ...entries];
  }
}
