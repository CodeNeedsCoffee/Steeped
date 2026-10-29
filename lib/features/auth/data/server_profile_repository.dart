import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/app_database.dart';

export '../../../core/storage/app_database.dart' show ServerProfile;

/// Key for a value in [KeyValueEntries] that belongs to one profile.
String profileScopedKey(String profileId, String key) => 'p:$profileId:$key';

/// QOL_PLAN E2: the list of servers/accounts the app knows about. Only
/// non-secret metadata; tokens live in [SessionStorage].
class ServerProfileRepository {
  ServerProfileRepository(this._db);

  final AppDatabase _db;

  static final _random = Random.secure();

  /// A new random profile id.
  static String newId() {
    final bytes = List<int>.generate(12, (_) => _random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  Stream<List<ServerProfile>> watchAll() {
    return (_db.select(_db.serverProfiles)..orderBy([
          (t) => OrderingTerm.desc(t.lastUsedAt),
          (t) => OrderingTerm.asc(t.serverUrl),
        ]))
        .watch();
  }

  Future<List<ServerProfile>> all() {
    return (_db.select(_db.serverProfiles)..orderBy([
          (t) => OrderingTerm.desc(t.lastUsedAt),
          (t) => OrderingTerm.asc(t.serverUrl),
        ]))
        .get();
  }

  Future<ServerProfile?> find(String id) {
    return (_db.select(
      _db.serverProfiles,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<ServerProfile?> findByServerAndUser(
    String serverUrl,
    String username,
  ) {
    return (_db.select(_db.serverProfiles)..where(
          (t) => t.serverUrl.equals(serverUrl) & t.username.equals(username),
        ))
        .getSingleOrNull();
  }

  Future<void> upsert({
    required String id,
    required String serverUrl,
    required String username,
    String userId = '',
    String displayName = '',
    int? lastUsedAt,
  }) {
    return _db
        .into(_db.serverProfiles)
        .insertOnConflictUpdate(
          ServerProfilesCompanion.insert(
            id: id,
            serverUrl: serverUrl,
            username: username,
            userId: Value(userId),
            displayName: Value(displayName),
            lastUsedAt: Value(
              lastUsedAt ?? DateTime.now().millisecondsSinceEpoch,
            ),
          ),
        );
  }

  Future<void> touch(String id) {
    return (_db.update(_db.serverProfiles)..where((t) => t.id.equals(id)))
        .write(
          ServerProfilesCompanion(
            lastUsedAt: Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );
  }

  /// Deletes the profile row and everything that is only meaningful with it
  /// (queued progress, profile-scoped caches). Downloads are handled by the
  /// caller because they own files on disk.
  Future<void> delete(String id) async {
    await _db.transaction(() async {
      await (_db.delete(
        _db.pendingProgressSyncs,
      )..where((t) => t.profileId.equals(id))).go();
      await (_db.delete(
        _db.keyValueEntries,
      )..where((t) => t.key.like('p:$id:%'))).go();
      await (_db.delete(
        _db.serverProfiles,
      )..where((t) => t.id.equals(id))).go();
    });
  }
}

final serverProfileRepositoryProvider = Provider<ServerProfileRepository>(
  (ref) => ServerProfileRepository(ref.watch(appDatabaseProvider)),
);

/// All saved profiles, most recently used first.
final serverProfilesProvider = StreamProvider<List<ServerProfile>>(
  (ref) => ref.watch(serverProfileRepositoryProvider).watchAll(),
);
