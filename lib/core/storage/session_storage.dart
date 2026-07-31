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

  static const _serverUrlKey = 'session.serverUrl';
  static const _accessTokenKey = 'session.accessToken';
  static const _refreshTokenKey = 'session.refreshToken';
  static const _legacyTokenKey = 'session.legacyToken';
  static const _userSnapshotKey = 'session.userSnapshot';

  Future<void> save({
    required String serverUrl,
    required AuthUser user,
  }) async {
    await Future.wait([
      _storage.write(key: _serverUrlKey, value: serverUrl),
      _writeOrDelete(_accessTokenKey, user.accessToken),
      _writeOrDelete(_refreshTokenKey, user.refreshToken),
      _writeOrDelete(_legacyTokenKey, user.legacyToken),
      _storage.write(
        key: _userSnapshotKey,
        value: jsonEncode({
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
            'selectedTagsNotAccessible':
                user.permissions.selectedTagsNotAccessible,
          },
          'librariesAccessible': user.permissions.librariesAccessible,
          'itemTagsSelected': user.permissions.itemTagsSelected,
        }),
      ),
    ]);
  }

  /// Updates just the tokens (used after a refresh), leaving the cached
  /// user snapshot and server URL untouched.
  Future<void> saveRefreshedTokens({
    required String? accessToken,
    required String? refreshToken,
  }) async {
    await Future.wait([
      _writeOrDelete(_accessTokenKey, accessToken),
      _writeOrDelete(_refreshTokenKey, refreshToken),
    ]);
  }

  Future<String?> readServerUrl() => _storage.read(key: _serverUrlKey);
  Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<String?> readEffectiveToken() async {
    final access = await _storage.read(key: _accessTokenKey);
    if (access != null) return access;
    return _storage.read(key: _legacyTokenKey);
  }

  /// Reconstructs an [AuthUser] from the cached snapshot + current tokens,
  /// without a network call. Used for the legacy-token path (no refresh
  /// endpoint exists on servers older than 2.26.0) and as an immediate
  /// placeholder while a JWT refresh is in flight.
  Future<AuthUser?> readCachedUser() async {
    final raw = await _storage.read(key: _userSnapshotKey);
    if (raw == null) return null;
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final accessToken = await _storage.read(key: _accessTokenKey);
    final refreshToken = await _storage.read(key: _refreshTokenKey);
    final legacyToken = await _storage.read(key: _legacyTokenKey);
    return AuthUser.fromJson({
      ...json,
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'token': legacyToken,
    });
  }

  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _serverUrlKey),
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
      _storage.delete(key: _legacyTokenKey),
      _storage.delete(key: _userSnapshotKey),
    ]);
  }

  Future<void> _writeOrDelete(String key, String? value) {
    if (value == null) return _storage.delete(key: key);
    return _storage.write(key: key, value: value);
  }
}

final sessionStorageProvider = Provider<SessionStorage>((ref) {
  return SessionStorage(ref.watch(secureStorageProvider));
});
