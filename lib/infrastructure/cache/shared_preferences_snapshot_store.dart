import 'package:shared_preferences/shared_preferences.dart';

import 'snapshot_store.dart';

/// [SnapshotStore] that keeps the snapshot as a single string under one
/// [SharedPreferences] key, which is enough for the size of a relation graph.
class SharedPreferencesSnapshotStore implements SnapshotStore {
  SharedPreferencesSnapshotStore(this._prefs, this._key);

  final SharedPreferences _prefs;
  final String _key;

  @override
  String? read() => _prefs.getString(_key);

  @override
  Future<void> write(String json) => _prefs.setString(_key, json);
}
