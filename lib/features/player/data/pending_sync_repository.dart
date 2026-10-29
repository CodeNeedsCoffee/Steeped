import 'package:drift/drift.dart';

import '../../../core/storage/app_database.dart';

/// PLAN.md Phase 6.7: durable storage for progress syncs that failed while
/// offline, so they survive an app restart and flush on the next real
/// reconnect rather than only "the next periodic tick while the app happens
/// to still be open."
class PendingSyncRepository {
  PendingSyncRepository(this._db, {this.profileId = ''});

  final AppDatabase _db;

  /// QOL_PLAN E2: the active server profile. Queued progress is tagged with
  /// the profile that owns the item and only uploaded while that profile is
  /// active, since the upload goes to that profile's server. The sync key
  /// stays per item (ids are server-unique UUIDs), which also keeps rows
  /// written before profiles existed addressable.
  final String profileId;

  static String _keyFor(String libraryItemId, String? episodeId) =>
      episodeId == null ? libraryItemId : '$libraryItemId::$episodeId';

  Future<void> enqueue({
    required String libraryItemId,
    String? episodeId,
    required double currentTime,
    required double duration,
    bool? isFinished,
    String? profileId,
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
            profileId: Value(profileId ?? this.profileId),
          ),
        );
  }

  Future<void> remove(String libraryItemId, String? episodeId) {
    return (_db.delete(_db.pendingProgressSyncs)..where(
          (t) => t.syncKey.equals(_keyFor(libraryItemId, episodeId)),
        ))
        .go();
  }

  /// Queued syncs that belong to the active profile.
  Future<List<PendingProgressSync>> pending() {
    return (_db.select(
      _db.pendingProgressSyncs,
    )..where((t) => t.profileId.equals(profileId))).get();
  }

  /// The still-unflushed sync (if any) for one item/episode — lets a caller
  /// compare a freshly-fetched server position against whatever more recent
  /// progress is durably queued locally but hasn't round-tripped yet.
  Future<PendingProgressSync?> find(String libraryItemId, String? episodeId) {
    return (_db.select(_db.pendingProgressSyncs)..where(
          (t) => t.syncKey.equals(_keyFor(libraryItemId, episodeId)),
        ))
        .getSingleOrNull();
  }

  Stream<int> watchPendingCount() {
    return (_db.select(_db.pendingProgressSyncs)
          ..where((t) => t.profileId.equals(profileId)))
        .watch()
        .map((rows) => rows.length);
  }
}
