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
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
  TextColumn get level => text()(); // info | warning | error
  TextColumn get tag => text()();
  TextColumn get message => text()();
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

@DriftDatabase(
  tables: [
    KeyValueEntries,
    DownloadedItems,
    DownloadedTracks,
    LogEntries,
    PendingProgressSyncs,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // Dev-time only: schema is still churning pre-release, so a schema
      // bump just rebuilds tables rather than carrying a real migration.
      for (final table in allTables) {
        await m.deleteTable(table.actualTableName);
      }
      await m.createAll();
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
