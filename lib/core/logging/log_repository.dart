import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/app_database.dart';

/// PLAN.md Phase 9.6: a real debug log evan can read on-device without
/// `adb logcat` — persisted so it survives app restarts, capped so it can't
/// grow unbounded on a long-running session.
class LogRepository {
  LogRepository(this._db);

  final AppDatabase _db;

  static const _maxEntries = 500;

  Future<void> log(String level, String tag, String message) async {
    await _db
        .into(_db.logEntries)
        .insert(
          LogEntriesCompanion.insert(level: level, tag: tag, message: message),
        );
    final count = await _db.select(_db.logEntries).get().then((l) => l.length);
    if (count > _maxEntries) {
      final oldest =
          await (_db.select(_db.logEntries)
                ..orderBy([(t) => OrderingTerm.asc(t.timestamp)])
                ..limit(count - _maxEntries))
              .get();
      for (final row in oldest) {
        await (_db.delete(
          _db.logEntries,
        )..where((t) => t.id.equals(row.id))).go();
      }
    }
  }

  Stream<List<LogEntry>> watchLogs() {
    return (_db.select(_db.logEntries)
          ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]))
        .watch();
  }

  Future<void> clear() => _db.delete(_db.logEntries).go();
}

final logRepositoryProvider = Provider<LogRepository>((ref) {
  return LogRepository(ref.watch(appDatabaseProvider));
});
