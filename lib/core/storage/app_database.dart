import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'app_database.g.dart';

/// Generic key/value store for simple app-level flags that don't yet warrant
/// a dedicated table.
class KeyValueEntries extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// PLAN.md Phase 6.4: local record of a server item downloaded for offline
/// use. `chaptersJson`/`coverLocalPath` let [DownloadRepository] rebuild a
/// full playable item with zero network access — the thing that makes 6.6
/// (offline playback) actually offline rather than "streams from cache."
class DownloadedItems extends Table {
  TextColumn get itemId => text()();
  TextColumn get serverUrl => text()();
  TextColumn get title => text()();
  TextColumn get authorNames => text().withDefault(const Constant(''))();
  RealColumn get totalDuration => real().nullable()();
  TextColumn get chaptersJson => text().nullable()();
  TextColumn get coverLocalPath => text().nullable()();
  TextColumn get status =>
      text().withDefault(const Constant('downloading'))(); // downloading | complete
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  // Local cache of listening progress, seeded at download time and kept
  // fresh by PlaybackController on every sync — this is what a downloaded
  // item resumes from when played with no network to ask the server.
  RealColumn get progressCurrentTime => real().nullable()();
  BoolColumn get progressIsFinished =>
      boolean().withDefault(const Constant(false))();
  // Which library this item came from, so an offline cold start can still
  // group downloads under the library picker. Nullable: rows written before
  // this column existed have no value, and consumers treat null as "show
  // under every library" rather than hiding a real downloaded book.
  TextColumn get libraryId => text().nullable()();

  @override
  Set<Column> get primaryKey => {itemId};
}

class DownloadedTracks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get itemId => text().references(DownloadedItems, #itemId)();
  IntColumn get trackIndex => integer()();
  RealColumn get startOffset => real()();
  RealColumn get duration => real()();
  TextColumn get localPath => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
}

/// PLAN.md Phase 9.6: a genuinely useful debug log, not a stub — hooked
/// into real failure paths (auth refresh, progress sync, downloads) so
/// evan can see what actually went wrong on a self-hosted connection
/// without needing `adb logcat`.
class LogEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  /// Most recent occurrence — an entry repeated back-to-back updates this
  /// rather than inserting again, so a persistently-failing operation stays
  /// sorted by when it last happened.
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
  TextColumn get level => text()(); // info | warning | error
  TextColumn get tag => text()();
  TextColumn get message => text()();
  /// How many times this identical entry has occurred in a row. A retry loop
  /// (a socket reconnecting every 5s with no network) would otherwise emit
  /// hundreds of byte-identical rows and evict every useful entry under the
  /// size cap — collapsing them keeps the count visible without the flood.
  IntColumn get repeatCount => integer().withDefault(const Constant(1))();
}

/// PLAN.md Phase 6.7: a real durable queue for progress syncs that failed
/// while offline — survives app restarts, unlike the prior best-effort
/// design that only caught up if the app happened to still be open on the
/// next 15s tick when connectivity returned. One row per item/episode
/// ([syncKey]); a later failed sync overwrites the earlier one since only
/// the latest position is worth uploading.
class PendingProgressSyncs extends Table {
  TextColumn get syncKey => text()(); // libraryItemId, or 'id::episodeId'
  TextColumn get libraryItemId => text()();
  TextColumn get episodeId => text().nullable()();
  RealColumn get currentTime => real()();
  RealColumn get duration => real()();
  BoolColumn get isFinished => boolean().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {syncKey};
}

/// PLAN.md Phase 6.8: on-device audio files imported directly (never from
/// the server) — a genuinely separate feature from downloading server
/// items. No server item id, no progress-sync endpoint to call; progress is
/// tracked purely locally via [progressCurrentTime].
class LocalMediaItems extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get localPath => text()();
  RealColumn get durationSeconds => real().nullable()();
  RealColumn get progressCurrentTime => real().nullable()();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    KeyValueEntries,
    DownloadedItems,
    DownloadedTracks,
    LogEntries,
    PendingProgressSyncs,
    LocalMediaItems,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 8;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 5) {
        // Dev-time only: schema was still churning pre-release, so earlier
        // bumps just rebuilt tables rather than carrying a real migration.
        // That's no longer free now that a real logged-in session (Phase 3)
        // gets discarded by it too — from here on, additive changes get a
        // real (if minimal) migration instead.
        for (final table in allTables) {
          await m.deleteTable(table.actualTableName);
        }
        await m.createAll();
        return;
      }
      if (from < 6) {
        await m.createTable(localMediaItems);
      }
      if (from < 7) {
        await m.addColumn(downloadedItems, downloadedItems.libraryId);
      }
      if (from < 8) {
        await m.addColumn(logEntries, logEntries.repeatCount);
      }
    },
  );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'steeped');
  }
}

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
