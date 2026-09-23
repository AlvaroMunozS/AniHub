import 'package:anihub/infrastructure/local/sqflite_entry_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../support/entry_repository_contract.dart';

void main() {
  sqfliteFfiInit();

  entryRepositoryContract((DateTime Function() now) async {
    final Database db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        singleInstance: false,
        onCreate: (Database db, int _) => createAniHubSchema(db),
      ),
    );
    final SqfliteEntryRepository repo = SqfliteEntryRepository(db, now: now);
    addTearDown(() async {
      await repo.dispose();
      await db.close();
    });
    return repo;
  }, constraintError: isA<DatabaseException>());
}
