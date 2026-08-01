import 'package:drift/drift.dart';

import '../../../core/storage/app_database.dart';

/// PLAN.md Phase 6.7: durable storage for progress syncs that failed while
/// offline, so they survive an app restart and flush on the next real
/// reconnect rather than only "the next periodic tick while the app happens
/// to still be open."
class PendingSyncRepository {
  PendingSyncRepository(this._db);

  final AppDatabase _db;

  static String _keyFor(String libraryItemId, String? episodeId) =>
      episodeId == null ? libraryItemId : '$libraryItemId::$episodeId';

  Future<void> enqueue({
    required String libraryItemId,
    String? episodeId,
    required double currentTime,
    required double duration,
    bool? isFinished,
  }) {
    return _db
        .into(_db.pendingProgressSyncs)
        .insertOnConflictUpdate(
          PendingProgressSyncsCompanion.insert(
            syncKey: _keyFor(libraryItemId, episodeId),
            libraryItemId: libraryItemId,
            episodeId: Value(episodeId),
            currentTime: currentTime,
            duration: duration,
            isFinished: Value(isFinished),
          ),
        );
  }

  Future<void> remove(String libraryItemId, String? episodeId) {
    return (_db.delete(_db.pendingProgressSyncs)..where(
          (t) => t.syncKey.equals(_keyFor(libraryItemId, episodeId)),
        ))
        .go();
  }

  Future<List<PendingProgressSync>> pending() {
    return _db.select(_db.pendingProgressSyncs).get();
  }

  Stream<int> watchPendingCount() {
    return _db
        .select(_db.pendingProgressSyncs)
        .watch()
        .map((rows) => rows.length);
  }
}
