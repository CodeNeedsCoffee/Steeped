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

  /// Trimming used to read the *entire* table back into Dart just to call
  /// `.length` on it, then issue one DELETE per excess row. At the 500-entry
  /// cap that's 500 rows materialised and shipped across the database isolate
  /// boundary on every single log write — including the ones written from a
  /// failing 15s progress sync, which is exactly when the device has the
  /// least to spare (bug fix 2026-08-05, evan: playback staggering). A
  /// `COUNT(*)` plus one bounded DELETE does the same job.
  ///
  /// Trims by `id` rather than `timestamp`: it's the autoincrement insertion
  /// order, so unlike `timestamp` it can't tie between two entries written in
  /// the same instant and leave the table one over the cap forever.
  Future<void> log(String level, String tag, String message) async {
    await _db
        .into(_db.logEntries)
        .insert(
          LogEntriesCompanion.insert(level: level, tag: tag, message: message),
        );

    final total = countAll();
    final countRow = await (_db.selectOnly(_db.logEntries)
          ..addColumns([total]))
        .getSingle();
    if ((countRow.read(total) ?? 0) <= _maxEntries) return;

    // The oldest entry worth keeping; everything before it goes in one go.
    final oldestKept =
        await (_db.select(_db.logEntries)
              ..orderBy([(t) => OrderingTerm.desc(t.id)])
              ..limit(1, offset: _maxEntries - 1))
            .getSingleOrNull();
    if (oldestKept == null) return;
    await (_db.delete(
      _db.logEntries,
    )..where((t) => t.id.isSmallerThanValue(oldestKept.id))).go();
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
