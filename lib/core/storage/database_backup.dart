import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

/// QOL_PLAN E2 risk note: before a schema upgrade rewrites tables, keep a
/// copy of the database as it was. Called from `main` before the database is
/// opened; any failure is swallowed (a missing backup must not stop the app).
///
/// Only the latest backup per old version is kept
/// (`steeped.sqlite.bak-v8`), so this costs one extra database-sized file
/// after an upgrade and nothing on ordinary launches.
Future<File?> backupDatabaseBeforeUpgrade({
  required int currentSchemaVersion,
  String name = 'steeped',
  Directory? directory,
}) async {
  try {
    final dir = directory ?? await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, '$name.sqlite'));
    if (!await file.exists()) return null;
    final oldVersion = readUserVersion(file);
    if (oldVersion == null ||
        oldVersion == 0 ||
        oldVersion >= currentSchemaVersion) {
      return null;
    }
    final backup = File('${file.path}.bak-v$oldVersion');
    return await file.copy(backup.path);
  } catch (_) {
    return null;
  }
}

/// SQLite's `PRAGMA user_version` (drift stores the schema version there).
int? readUserVersion(File file) {
  final db = sqlite3.open(file.path, mode: OpenMode.readOnly);
  try {
    return db.select('PRAGMA user_version').first.values.first as int;
  } finally {
    db.dispose();
  }
}
