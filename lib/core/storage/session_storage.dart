import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../models/auth_user.dart';
import 'secure_storage.dart';

/// Persists the active server connection + auth tokens (Keychain on iOS,
/// Keystore on Android via [secureStorageProvider]). A `userSnapshot` is
/// also cached so the UI has something to show immediately on cold start,
/// before a token refresh (or, for legacy-token servers with no refresh
/// endpoint, indefinitely) confirms it's still valid.
class SessionStorage {
  SessionStorage(this._storage);

  final FlutterSecureStorage _storage;

  // --- QOL_PLAN E2: tokens are stored per server profile -------------------
  //
  // Everything below operates on the *active* profile unless a `profileId`
  // is passed. Long-running work (a token refresh) captures the profile id
  // when it starts and passes it back, so a switch mid-flight can never
  // write one account's tokens into another's slot.

  static const _activeProfileKey = 'session.activeProfile';
  static String _key(String profileId, String field) =>
      'profile:$profileId:$field';

  // Pre-profile single-session keys, read only by [ProfileMigrator].
  static const _legacyServerUrlKey = 'session.serverUrl';
  static const _legacyAccessTokenKey = 'session.accessToken';
  static const _legacyRefreshTokenKey = 'session.refreshToken';
  static const _legacyLegacyTokenKey = 'session.legacyToken';
  static const _legacyUserSnapshotKey = 'session.userSnapshot';

  String? _activeId;
  bool _activeLoaded = false;

  /// The active profile id (null when signed out). Cached after the first
  /// read; [setActiveProfileId] keeps it current.
  Future<String?> readActiveProfileId() async {
    if (!_activeLoaded) {
      _activeId = await _storage.read(key: _activeProfileKey);
      _activeLoaded = true;
    }
    return _activeId;
  }

  Future<void> setActiveProfileId(String? id) async {
    _activeId = id;
    _activeLoaded = true;
    if (id == null) {
      await _storage.delete(key: _activeProfileKey);
    } else {
      await _storage.write(key: _activeProfileKey, value: id);
    }
  }

  Future<String> _profile(String? explicit) async {
    final id = explicit ?? await readActiveProfileId();
    if (id == null) throw StateError('No active server profile');
    return id;
  }

  Future<void> save({
    required String serverUrl,
    required AuthUser user,
    String? profileId,
  }) async {
    final id = await _profile(profileId);
    await Future.wait([
      _storage.write(key: _key(id, 'serverUrl'), value: serverUrl),
      _writeOrDelete(_key(id, 'accessToken'), user.accessToken),
      _writeOrDelete(_key(id, 'refreshToken'), user.refreshToken),
      _writeOrDelete(_key(id, 'legacyToken'), user.legacyToken),
      _storage.write(
        key: _key(id, 'userSnapshot'),
        value: jsonEncode(snapshotJson(user)),
      ),
    ]);
  }

  /// The JSON stored as a profile's cached user (permissions included).
  static Map<String, dynamic> snapshotJson(AuthUser user) => {
    'id': user.id,
    'username': user.username,
    'email': user.email,
    'type': user.type,
    'isActive': user.isActive,
    'isLocked': user.isLocked,
    'hasOpenIDLink': user.hasOpenIDLink,
    'permissions': {
      'download': user.permissions.download,
      'update': user.permissions.update,
      'delete': user.permissions.delete,
      'upload': user.permissions.upload,
      'createEreader': user.permissions.createEreader,
      'accessAllLibraries': user.permissions.accessAllLibraries,
      'accessAllTags': user.permissions.accessAllTags,
      'accessExplicitContent': user.permissions.accessExplicitContent,
      'selectedTagsNotAccessible': user.permissions.selectedTagsNotAccessible,
    },
    'librariesAccessible': user.permissions.librariesAccessible,
    'itemTagsSelected': user.permissions.itemTagsSelected,
  };

  /// Updates just the tokens (used after a refresh), leaving the cached
  /// user snapshot and server URL untouched.
  Future<void> saveRefreshedTokens({
    required String? accessToken,
    required String? refreshToken,
    String? profileId,
  }) async {
    final id = await _profile(profileId);
    await Future.wait([
      _writeOrDelete(_key(id, 'accessToken'), accessToken),
      _writeOrDelete(_key(id, 'refreshToken'), refreshToken),
    ]);
  }

  Future<String?> readServerUrl({String? profileId}) async =>
      _storage.read(key: _key(await _profile(profileId), 'serverUrl'));

  Future<String?> readRefreshToken({String? profileId}) async =>
      _storage.read(key: _key(await _profile(profileId), 'refreshToken'));

  Future<String?> readEffectiveToken({String? profileId}) async {
    final id = await _profile(profileId);
    final access = await _storage.read(key: _key(id, 'accessToken'));
    if (access != null) return access;
    return _storage.read(key: _key(id, 'legacyToken'));
  }

  /// Whether [profileId] still holds credentials (it doesn't after a forced
  /// sign-out of just that account).
  Future<bool> hasCredentials(String profileId) async {
    return await _storage.read(key: _key(profileId, 'accessToken')) != null ||
        await _storage.read(key: _key(profileId, 'legacyToken')) != null ||
        await _storage.read(key: _key(profileId, 'refreshToken')) != null;
  }

  /// Reconstructs an [AuthUser] from the cached snapshot + current tokens,
  /// without a network call. Used for the legacy-token path (no refresh
  /// endpoint exists on servers older than 2.26.0) and as an immediate
  /// placeholder while a JWT refresh is in flight.
  Future<AuthUser?> readCachedUser({String? profileId}) async {
    final id = await _profile(profileId);
    final raw = await _storage.read(key: _key(id, 'userSnapshot'));
    if (raw == null) return null;
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final accessToken = await _storage.read(key: _key(id, 'accessToken'));
    final refreshToken = await _storage.read(key: _key(id, 'refreshToken'));
    final legacyToken = await _storage.read(key: _key(id, 'legacyToken'));
    return AuthUser.fromJson({
      ...json,
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'token': legacyToken,
    });
  }

  /// Removes one profile's credentials (the active one by default). Other
  /// profiles are never touched. Leaves the active-profile pointer alone;
  /// callers decide what becomes active next.
  Future<void> clear({String? profileId}) async {
    final id = profileId ?? _activeId ?? await readActiveProfileId();
    if (id == null) return;
    await Future.wait([
      for (final f in const [
        'serverUrl',
        'accessToken',
        'refreshToken',
        'legacyToken',
        'userSnapshot',
      ])
        _storage.delete(key: _key(id, f)),
    ]);
  }

  // --- pre-profile session, for the first-launch migration -----------------

  /// The old single session, or null if there isn't one.
  Future<LegacySession?> readLegacySession() async {
    final serverUrl = await _storage.read(key: _legacyServerUrlKey);
    if (serverUrl == null) return null;
    return LegacySession(
      serverUrl: serverUrl,
      accessToken: await _storage.read(key: _legacyAccessTokenKey),
      refreshToken: await _storage.read(key: _legacyRefreshTokenKey),
      legacyToken: await _storage.read(key: _legacyLegacyTokenKey),
      userSnapshot: await _storage.read(key: _legacyUserSnapshotKey),
    );
  }

  /// Writes a migrated legacy session into [profileId]'s slots.
  Future<void> importLegacySession(String profileId, LegacySession s) async {
    await Future.wait([
      _storage.write(key: _key(profileId, 'serverUrl'), value: s.serverUrl),
      _writeOrDelete(_key(profileId, 'accessToken'), s.accessToken),
      _writeOrDelete(_key(profileId, 'refreshToken'), s.refreshToken),
      _writeOrDelete(_key(profileId, 'legacyToken'), s.legacyToken),
      _writeOrDelete(_key(profileId, 'userSnapshot'), s.userSnapshot),
    ]);
  }

  /// Deletes the pre-profile keys. Only called after the copy above and the
  /// database reassignment both succeeded.
  Future<void> clearLegacySession() async {
    await Future.wait([
      _storage.delete(key: _legacyServerUrlKey),
      _storage.delete(key: _legacyAccessTokenKey),
      _storage.delete(key: _legacyRefreshTokenKey),
      _storage.delete(key: _legacyLegacyTokenKey),
      _storage.delete(key: _legacyUserSnapshotKey),
    ]);
  }

  Future<void> _writeOrDelete(String key, String? value) {
    if (value == null) return _storage.delete(key: key);
    return _storage.write(key: key, value: value);
  }
}

class LegacySession {
  const LegacySession({
    required this.serverUrl,
    this.accessToken,
    this.refreshToken,
    this.legacyToken,
    this.userSnapshot,
  });

  final String serverUrl;
  final String? accessToken;
  final String? refreshToken;
  final String? legacyToken;
  final String? userSnapshot;
}

final sessionStorageProvider = Provider<SessionStorage>((ref) {
  return SessionStorage(ref.watch(secureStorageProvider));
});
