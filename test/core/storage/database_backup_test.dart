import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:steeped/core/storage/database_backup.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('backup_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  File makeDb(int version) {
    final f = File('${dir.path}/steeped.sqlite');
    final db = sqlite3.open(f.path);
    db.execute('CREATE TABLE t (x INTEGER); INSERT INTO t VALUES (7);');
    db.execute('PRAGMA user_version = $version');
    db.dispose();
    return f;
  }

  test('copies the database when an upgrade is coming', () async {
    makeDb(8);
    final backup = await backupDatabaseBeforeUpgrade(
      currentSchemaVersion: 9,
      directory: dir,
    );
    expect(backup, isNotNull);
    expect(backup!.path, endsWith('steeped.sqlite.bak-v8'));
    final copy = sqlite3.open(backup.path, mode: OpenMode.readOnly);
    expect(copy.select('SELECT x FROM t').first['x'], 7);
    copy.dispose();
  });

  test('does nothing when already current, fresh, or missing', () async {
    expect(
      await backupDatabaseBeforeUpgrade(currentSchemaVersion: 9, directory: dir),
      isNull,
    );
    makeDb(9);
    expect(
      await backupDatabaseBeforeUpgrade(currentSchemaVersion: 9, directory: dir),
      isNull,
    );
  });
}
