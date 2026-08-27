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

  /// Entries older than this are dropped at startup (see [purgeOldEntries]).
  /// A week is long enough to still investigate "it broke yesterday evening"
  /// without carrying months of dead noise forever.
  static const retentionPeriod = Duration(days: 7);

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
    // Collapse a repeat of whatever was logged last instead of inserting a
    // duplicate row. Only the immediately-previous entry is compared: a
    // retry loop emits its identical failures consecutively, which is the
    // flood worth folding, while the same message recurring later still
    // gets its own row rather than silently bumping an old count.
    final previous =
        await (_db.select(_db.logEntries)
              ..orderBy([(t) => OrderingTerm.desc(t.id)])
              ..limit(1))
            .getSingleOrNull();
    if (previous != null &&
        previous.level == level &&
        previous.tag == tag &&
        previous.message == message) {
      await (_db.update(
        _db.logEntries,
      )..where((t) => t.id.equals(previous.id))).write(
        LogEntriesCompanion(
          timestamp: Value(DateTime.now()),
          repeatCount: Value(previous.repeatCount + 1),
        ),
      );
      return;
    }

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

  /// Drops entries older than [retentionPeriod]. Called once at startup
  /// rather than on every write: the [_maxEntries] cap already bounds the
  /// table between runs, so this only needs to catch entries that aged out
  /// while under that cap (a quiet week leaves old rows sitting forever).
  Future<int> purgeOldEntries() {
    final cutoff = DateTime.now().subtract(retentionPeriod);
    return (_db.delete(
      _db.logEntries,
    )..where((t) => t.timestamp.isSmallerThanValue(cutoff))).go();
  }

  Future<void> clear() => _db.delete(_db.logEntries).go();
}

final logRepositoryProvider = Provider<LogRepository>((ref) {
  return LogRepository(ref.watch(appDatabaseProvider));
});
