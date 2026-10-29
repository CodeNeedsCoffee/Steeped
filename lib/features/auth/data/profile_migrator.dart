import 'dart:convert';

import 'package:drift/drift.dart' show Variable;

import '../../../core/storage/app_database.dart';
import '../../../core/storage/session_storage.dart';
import 'server_profile_repository.dart';

/// QOL_PLAN E2.1: the one-time move from "a single signed-in session" to
/// server profiles, run on the first launch of the version that has them.
///
/// The old session becomes profile #1: its tokens are copied under
/// `profile:<id>:*`, its downloads/queued progress/caches are tagged with
/// the new id, and only then is the old keyed session deleted. Nobody is
/// logged out and nothing is lost. Safe to re-run after a crash at any
/// point: it reuses a profile already created for the same server+user.
class ProfileMigrator {
  ProfileMigrator({
    required this.db,
    required this.storage,
    required this.profiles,
    String Function()? newId,
  }) : _newId = newId ?? ServerProfileRepository.newId;

  final AppDatabase db;
  final SessionStorage storage;
  final ServerProfileRepository profiles;
  final String Function() _newId;

  /// KV keys that used to be global and are now per profile.
  static const scopedKeys = ['cached_libraries', 'recent_searches'];

  /// Returns the active profile id after migrating if needed, or null when
  /// there is no session at all.
  Future<String?> migrateIfNeeded() async {
    final active = await storage.readActiveProfileId();
    if (active != null) return active;

    final legacy = await storage.readLegacySession();
    if (legacy == null) return null;

    var username = '';
    var userId = '';
    var displayName = '';
    final snapshot = legacy.userSnapshot;
    if (snapshot != null) {
      try {
        final json = jsonDecode(snapshot) as Map<String, dynamic>;
        username = json['username'] as String? ?? '';
        userId = json['id'] as String? ?? '';
        displayName = username;
      } catch (_) {
        // A corrupt snapshot only costs us the label.
      }
    }

    final existing = await profiles.findByServerAndUser(
      legacy.serverUrl,
      username,
    );
    final id = existing?.id ?? _newId();

    await storage.importLegacySession(id, legacy);
    await db.transaction(() async {
      await profiles.upsert(
        id: id,
        serverUrl: legacy.serverUrl,
        username: username,
        userId: userId,
        displayName: displayName,
      );
      // Only downloads that came from this server; ones from a server the
      // user has since left stay unassigned and are listed as "other".
      await db.customUpdate(
        "UPDATE downloaded_items SET profile_id = ? "
        "WHERE profile_id = '' AND server_url = ?",
        variables: [
          Variable<String>(id),
          Variable<String>(legacy.serverUrl),
        ],
        updates: {db.downloadedItems},
      );
      await db.customUpdate(
        "UPDATE pending_progress_syncs SET profile_id = ? "
        "WHERE profile_id = ''",
        variables: [Variable<String>(id)],
        updates: {db.pendingProgressSyncs},
      );
      for (final key in scopedKeys) {
        await db.customUpdate(
          'UPDATE key_value_entries SET "key" = ? WHERE "key" = ?',
          variables: [
            Variable<String>(profileScopedKey(id, key)),
            Variable<String>(key),
          ],
          updates: {db.keyValueEntries},
        );
      }
    });
    await storage.setActiveProfileId(id);
    await storage.clearLegacySession();
    return id;
  }
}
