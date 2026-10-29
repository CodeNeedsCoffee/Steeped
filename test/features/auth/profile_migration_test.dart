import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steeped/core/storage/app_database.dart';
import 'package:steeped/core/storage/session_storage.dart';
import 'package:steeped/features/auth/data/profile_migrator.dart';
import 'package:steeped/features/auth/data/server_profile_repository.dart';

const _snapshot = {'id': 'u1', 'username': 'evan', 'type': 'user'};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('schema v8 -> v9', () {
    test('adds profile tables/columns without touching existing rows', () async {
      final executor = NativeDatabase.memory(
        setup: (raw) {
          raw.execute('''
            CREATE TABLE downloaded_items (
              item_id TEXT NOT NULL PRIMARY KEY, server_url TEXT NOT NULL,
              title TEXT NOT NULL, author_names TEXT NOT NULL DEFAULT '',
              total_duration REAL, chapters_json TEXT, cover_local_path TEXT,
              status TEXT NOT NULL DEFAULT 'downloading',
              created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s','now') AS INTEGER)),
              progress_current_time REAL,
              progress_is_finished INTEGER NOT NULL DEFAULT 0 CHECK (progress_is_finished IN (0, 1)),
              library_id TEXT);
          ''');
          raw.execute('''
            CREATE TABLE pending_progress_syncs (
              sync_key TEXT NOT NULL PRIMARY KEY, library_item_id TEXT NOT NULL,
              episode_id TEXT, current_time REAL NOT NULL, duration REAL NOT NULL,
              is_finished INTEGER CHECK (is_finished IN (0, 1)),
              updated_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s','now') AS INTEGER)));
          ''');
          raw.execute(
            "INSERT INTO downloaded_items (item_id, server_url, title) VALUES ('b1','https://a.test','Book')",
          );
          raw.execute(
            "INSERT INTO pending_progress_syncs (sync_key, library_item_id, current_time, duration) VALUES ('b1','b1',5,10)",
          );
          raw.execute('PRAGMA user_version = 8');
        },
      );
      final db = AppDatabase.forTesting(executor);
      addTearDown(db.close);

      final item = await db.select(db.downloadedItems).getSingle();
      expect(item.itemId, 'b1');
      expect(item.profileId, '');
      final sync = await db.select(db.pendingProgressSyncs).getSingle();
      expect(sync.profileId, '');
      expect(await db.select(db.serverProfiles).get(), isEmpty);
    });
  });

  group('ProfileMigrator', () {
    late AppDatabase db;
    late SessionStorage storage;
    late ServerProfileRepository profiles;
    var counter = 0;

    ProfileMigrator migrator() => ProfileMigrator(
      db: db,
      storage: storage,
      profiles: profiles,
      newId: () => 'profile-${++counter}',
    );

    setUp(() {
      counter = 0;
      FlutterSecureStorage.setMockInitialValues({
        'session.serverUrl': 'https://a.test',
        'session.accessToken': 'acc',
        'session.refreshToken': 'ref',
        'session.userSnapshot': jsonEncode(_snapshot),
      });
      db = AppDatabase.forTesting(NativeDatabase.memory());
      storage = SessionStorage(const FlutterSecureStorage());
      profiles = ServerProfileRepository(db);
    });
    tearDown(() => db.close());

    Future<void> seed() async {
      await db.into(db.downloadedItems).insert(
        DownloadedItemsCompanion.insert(
          itemId: 'mine',
          serverUrl: 'https://a.test',
          title: 'Mine',
        ),
      );
      await db.into(db.downloadedItems).insert(
        DownloadedItemsCompanion.insert(
          itemId: 'old',
          serverUrl: 'https://gone.test',
          title: 'From a server the user left',
        ),
      );
      await db.into(db.pendingProgressSyncs).insert(
        PendingProgressSyncsCompanion.insert(
          syncKey: 'mine',
          libraryItemId: 'mine',
          currentTime: 1,
          duration: 2,
        ),
      );
      for (final k in ['cached_libraries', 'recent_searches', 'library_query:l1']) {
        await db.into(db.keyValueEntries).insert(
          KeyValueEntriesCompanion.insert(key: k, value: '[]'),
        );
      }
    }

    test('moves the single session into profile #1 and reassigns its data', () async {
      await seed();
      final id = await migrator().migrateIfNeeded();

      expect(id, 'profile-1');
      expect(await storage.readActiveProfileId(), 'profile-1');
      expect(await storage.readEffectiveToken(), 'acc');
      expect(await storage.readRefreshToken(), 'ref');
      expect(await storage.readServerUrl(), 'https://a.test');
      expect((await storage.readCachedUser())?.username, 'evan');

      final all = await profiles.all();
      expect(all.single.username, 'evan');
      expect(all.single.serverUrl, 'https://a.test');

      final items = {
        for (final i in await db.select(db.downloadedItems).get())
          i.itemId: i.profileId,
      };
      expect(items['mine'], 'profile-1');
      expect(items['old'], '', reason: 'other server stays unassigned');
      expect(
        (await db.select(db.pendingProgressSyncs).getSingle()).profileId,
        'profile-1',
      );

      final keys = (await db.select(db.keyValueEntries).get())
          .map((e) => e.key)
          .toSet();
      expect(keys, contains('p:profile-1:cached_libraries'));
      expect(keys, contains('p:profile-1:recent_searches'));
      expect(keys, contains('library_query:l1'));
      expect(keys, isNot(contains('cached_libraries')));

      expect(await storage.readLegacySession(), isNull);
    });

    test('is a no-op the second time', () async {
      await seed();
      await migrator().migrateIfNeeded();
      expect(await migrator().migrateIfNeeded(), 'profile-1');
      expect(await profiles.all(), hasLength(1));
    });

    test('reuses the profile if a crash left the legacy keys behind', () async {
      await seed();
      await migrator().migrateIfNeeded();
      // Simulate: legacy keys came back and the active pointer was lost.
      FlutterSecureStorage.setMockInitialValues({
        'session.serverUrl': 'https://a.test',
        'session.accessToken': 'acc2',
        'session.userSnapshot': jsonEncode(_snapshot),
      });
      storage = SessionStorage(const FlutterSecureStorage());
      expect(await migrator().migrateIfNeeded(), 'profile-1');
      expect(await profiles.all(), hasLength(1));
    });

    test('returns null when there is no session', () async {
      FlutterSecureStorage.setMockInitialValues({});
      storage = SessionStorage(const FlutterSecureStorage());
      expect(await migrator().migrateIfNeeded(), isNull);
    });
  });

  group('per-profile tokens', () {
    test('clearing one profile never touches another', () async {
      FlutterSecureStorage.setMockInitialValues({
        'profile:a:accessToken': 'ta',
        'profile:a:refreshToken': 'ra',
        'profile:b:accessToken': 'tb',
        'profile:b:refreshToken': 'rb',
      });
      final s = SessionStorage(const FlutterSecureStorage());
      await s.setActiveProfileId('a');
      expect(await s.readEffectiveToken(), 'ta');
      expect(await s.readEffectiveToken(profileId: 'b'), 'tb');

      await s.clear(profileId: 'a');
      expect(await s.hasCredentials('a'), isFalse);
      expect(await s.hasCredentials('b'), isTrue);
      expect(await s.readRefreshToken(profileId: 'b'), 'rb');
    });

    test('a refresh saved for profile b lands in b even if a is active', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final s = SessionStorage(const FlutterSecureStorage());
      await s.setActiveProfileId('a');
      await s.saveRefreshedTokens(
        accessToken: 'new',
        refreshToken: 'newr',
        profileId: 'b',
      );
      expect(await s.readEffectiveToken(profileId: 'b'), 'new');
      expect(await s.readEffectiveToken(profileId: 'a'), isNull);
    });
  });

  group('ServerProfileRepository.delete', () {
    test('removes the profile, its queued progress and scoped caches only', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = ServerProfileRepository(db);
      await repo.upsert(id: 'a', serverUrl: 'https://a', username: 'x');
      await repo.upsert(id: 'b', serverUrl: 'https://b', username: 'y');
      for (final p in ['a', 'b']) {
        await db.into(db.pendingProgressSyncs).insert(
          PendingProgressSyncsCompanion.insert(
            syncKey: 'k$p',
            libraryItemId: 'k$p',
            currentTime: 1,
            duration: 2,
            profileId: Value(p),
          ),
        );
        await db.into(db.keyValueEntries).insert(
          KeyValueEntriesCompanion.insert(
            key: profileScopedKey(p, 'recent_searches'),
            value: '[]',
          ),
        );
      }
      await repo.delete('a');
      expect((await repo.all()).map((p) => p.id), ['b']);
      expect(
        (await db.select(db.pendingProgressSyncs).get()).map((r) => r.profileId),
        ['b'],
      );
      expect(
        (await db.select(db.keyValueEntries).get()).map((r) => r.key),
        [profileScopedKey('b', 'recent_searches')],
      );
    });
  });
}
