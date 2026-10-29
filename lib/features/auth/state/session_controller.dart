import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/log_repository.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/socket_service.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/storage/session_storage.dart';
import '../../../models/server_status.dart';
import '../../settings/data/account_repository.dart';
import '../data/auth_repository.dart';
import '../data/profile_migrator.dart';
import '../data/server_profile_repository.dart';
import '../data/token_refresh_coordinator.dart';
import 'session_expired_signal.dart';
import 'session_state.dart';

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => AccountRepository(ref.watch(dioProvider)),
);

class SessionController extends Notifier<SessionState> {
  late final AuthRepository _repository;
  late final SessionStorage _storage;
  late final TokenRefreshCoordinator _coordinator;
  late final ServerProfileRepository _profiles;

  @override
  SessionState build() {
    _repository = ref.watch(authRepositoryProvider);
    _storage = ref.watch(sessionStorageProvider);
    _coordinator = ref.watch(tokenRefreshCoordinatorProvider);
    _profiles = ref.watch(serverProfileRepositoryProvider);

    // AuthInterceptor fires this when a background token refresh fails on
    // some unrelated API call; react by forcing the user back to login.
    ref.listen(sessionExpiredSignalProvider, (previous, next) {
      if (previous != null && next != previous) {
        state = const SessionUnauthenticated();
      }
    });

    unawaited(_bootstrap());
    return const SessionBootstrapping();
  }

  Future<void> _bootstrap() async {
    // QOL_PLAN E2.1: moves a pre-profile single session into profile #1
    // (no-op once done, or when there's no session).
    final profileId = await ProfileMigrator(
      db: ref.read(appDatabaseProvider),
      storage: _storage,
      profiles: _profiles,
    ).migrateIfNeeded();
    if (profileId == null) {
      state = const SessionUnauthenticated();
      return;
    }
    await _bootstrapProfile(profileId);
  }

  /// Restores the session of [profileId] (already the active profile in
  /// storage) -- shared by app start and account switching.
  Future<void> _bootstrapProfile(String profileId) async {
    final serverUrl = await _storage.readServerUrl(profileId: profileId);
    if (serverUrl == null) {
      state = const SessionUnauthenticated();
      return;
    }

    final refreshToken = await _storage.readRefreshToken(profileId: profileId);
    if (refreshToken != null) {
      // 2.26.0+ server: proactively refresh to confirm the session is
      // still valid and get current user/permissions data. Goes through
      // TokenRefreshCoordinator so this never races AuthInterceptor's or
      // SocketService's own reactive refreshes over the same refresh token
      // — see TokenRefreshCoordinator's doc comment.
      try {
        final user = await _coordinator.refresh(
          serverUrl: serverUrl,
          profileId: profileId,
        );
        await _storage.save(
          serverUrl: serverUrl,
          user: user,
          profileId: profileId,
        );
        await _profiles.touch(profileId);
        state = SessionAuthenticated(
          serverUrl: serverUrl,
          user: user,
          profileId: profileId,
        );
      } on StateError catch (e) {
        // The coordinator found no refresh token in storage by the time it
        // actually ran — same conclusion as a server-rejected refresh.
        await ref
            .read(logRepositoryProvider)
            .log(
              'error',
              'session',
              'Startup token refresh rejected by server: $e',
            );
        await _storage.clear(profileId: profileId);
        state = const SessionUnauthenticated();
        return;
      } on DioException catch (e) {
        // PLAN.md Phase 6.6 gap: a cold start with no network previously
        // couldn't tell "the refresh token is actually invalid" (a real
        // 401/403 response — the server rejected it) apart from "the
        // request never reached the server at all" — and cleared the whole
        // session on either. That locked a fully offline cold start out of
        // downloaded content it should still be able to play, and forced a
        // real re-login once connectivity came back for what was really
        // just a network blip. Only a genuine rejection from the server
        // should log the user out; anything else falls back to the cached
        // session, same as the legacy-token path below.
        if (e.type == DioExceptionType.badResponse) {
          await ref
              .read(logRepositoryProvider)
              .log(
                'error',
                'session',
                'Startup token refresh rejected by server: $e',
              );
          await _storage.clear(profileId: profileId);
          state = const SessionUnauthenticated();
          return;
        }
        await ref
            .read(logRepositoryProvider)
            .log(
              'warning',
              'session',
              'Startup token refresh unreachable, using cached session: $e',
            );
        final cachedUser = await _storage.readCachedUser(profileId: profileId);
        if (cachedUser?.effectiveToken != null) {
          state = SessionAuthenticated(
            serverUrl: serverUrl,
            user: cachedUser!,
            profileId: profileId,
          );
        } else {
          state = const SessionUnauthenticated();
        }
      }
      return;
    }

    // Legacy-token server (< 2.26.0): no refresh endpoint exists, so trust
    // the cached session until a 401 actually occurs.
    final cachedUser = await _storage.readCachedUser(profileId: profileId);
    if (cachedUser?.effectiveToken != null) {
      await _profiles.touch(profileId);
      state = SessionAuthenticated(
        serverUrl: serverUrl,
        user: cachedUser!,
        profileId: profileId,
      );
    } else {
      state = const SessionUnauthenticated();
    }
  }

  /// Normalizes [rawUrl] and checks `/status`. Returns the normalized URL
  /// alongside the result so callers (the connect-server screen) don't have
  /// to duplicate normalization when passing the URL on to [login].
  Future<(String url, ServerStatus status)> checkServer(String rawUrl) async {
    final url = AuthRepository.normalizeServerUrl(rawUrl);
    final status = await _repository.checkStatus(url);
    return (url, status);
  }

  /// Signs in and makes the account the active profile. Signing in to a
  /// server+user the app already knows reuses that profile (and so its
  /// downloads); anything else is a new profile alongside the existing ones.
  ///
  /// [beforeActivate] runs once the credentials are accepted but before the
  /// new account takes over, so a caller adding an account can stop
  /// playback while the previous account is still the active one.
  Future<void> login({
    required String serverUrl,
    required String username,
    required String password,
    Future<void> Function()? beforeActivate,
  }) async {
    final result = await _repository.login(
      serverUrl: serverUrl,
      username: username,
      password: password,
    );
    await beforeActivate?.call();
    final existing = await _profiles.findByServerAndUser(
      serverUrl,
      result.user.username,
    );
    final id = existing?.id ?? ServerProfileRepository.newId();
    await _storage.setActiveProfileId(id);
    await _storage.save(serverUrl: serverUrl, user: result.user, profileId: id);
    await _profiles.upsert(
      id: id,
      serverUrl: serverUrl,
      username: result.user.username,
      userId: result.user.id,
      displayName: result.user.username,
    );
    state = SessionAuthenticated(
      serverUrl: serverUrl,
      user: result.user,
      profileId: id,
    );
  }

  /// Makes [profileId] the active account and restores its session. Callers
  /// stop playback and reset account-scoped UI state first (see
  /// `ProfileSwitcher`). Passing through [SessionBootstrapping] unwinds the
  /// current screens, so the router rebuilds from the new account's home.
  Future<void> switchTo(String profileId) async {
    final current = state;
    if (current is SessionAuthenticated && current.profileId == profileId) {
      return;
    }
    state = const SessionBootstrapping();
    await _storage.setActiveProfileId(profileId);
    await _bootstrapProfile(profileId);
  }

  /// Signs out of the active account only: its tokens and profile entry go,
  /// every other account is untouched. Its downloads stay on the device.
  /// Falls back to the most recently used other account, if any.
  Future<void> logout() async {
    final current = state;
    if (current is! SessionAuthenticated) {
      await _storage.clear();
      state = const SessionUnauthenticated();
      return;
    }
    await removeProfile(current.profileId);
  }

  /// Forgets [profileId]: credentials, queued progress and caches. Downloads
  /// are kept here; callers that also want them gone delete them first (see
  /// `ProfileSwitcher.removeProfile`). If it was the active account, the next
  /// most recently used signed-in account takes over.
  Future<void> removeProfile(String profileId) async {
    final current = state;
    final wasActive =
        current is SessionAuthenticated && current.profileId == profileId;
    await _storage.clear(profileId: profileId);
    await _profiles.delete(profileId);
    if (!wasActive) return;

    String? next;
    for (final p in await _profiles.all()) {
      if (await _storage.hasCredentials(p.id)) {
        next = p.id;
        break;
      }
    }
    if (next == null) {
      await _storage.setActiveProfileId(null);
      state = const SessionUnauthenticated();
    } else {
      await switchTo(next);
    }
  }

  /// Bug found 2026-08-03 (reported by evan: streamed playback appeared to
  /// start after a long idle period but the position never advanced).
  /// [AuthInterceptor] (on a REST 401) and [SocketService] (on a socket
  /// `auth_failed`) both reactively refresh an expired token and persist it
  /// via `SessionStorage.saveRefreshedTokens` — but neither had any way to
  /// update *this* in-memory state. Anything reading `session.user
  /// .effectiveToken` directly (e.g. `PlaybackController` building a stream
  /// URL) kept using the stale pre-refresh token until the next full app
  /// restart, even though storage and every dio-routed call had already
  /// moved on to the fresh one — confirmed live via the Logs screen: a
  /// socket-triggered refresh at 18:00:40, then two identical `(0) Source
  /// error` playback failures at 18:00:57/18:01:05 for the same stale
  /// token. Call this right after any reactive refresh so the two never
  /// diverge again.
  void updateTokens({required String? accessToken, required String? refreshToken}) {
    final current = state;
    if (current is! SessionAuthenticated) return;
    state = SessionAuthenticated(
      serverUrl: current.serverUrl,
      user: current.user.copyWith(
        accessToken: accessToken,
        refreshToken: refreshToken,
      ),
      profileId: current.profileId,
    );
    // Pokes an existing `authFailed` socket to retry with this freshly
    // rotated token — see SocketService.reauthenticateIfNeeded for why
    // nothing else does this automatically.
    ref.read(socketServiceProvider.notifier).reauthenticateIfNeeded();
  }

  /// Changes the signed-in user's password. Lives here rather than in the
  /// screen because a successful change *rotates this session's tokens* —
  /// the server invalidates the user's other JWT sessions and issues
  /// replacements for this one — so storage and in-memory state both have to
  /// move together, exactly as [updateTokens]' note above describes.
  ///
  /// Throws [DioException] on failure so the caller can map status codes to
  /// user-facing copy.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final current = state;
    if (current is! SessionAuthenticated) return;

    final tokens = await ref
        .read(accountRepositoryProvider)
        .changePassword(
          currentPassword: currentPassword,
          newPassword: newPassword,
          refreshToken: current.user.refreshToken,
        );

    // Null on a pre-2.26.0 server: nothing was rotated, and the existing
    // legacy token stays valid, so there's nothing to persist.
    if (tokens.accessToken == null) return;
    await _storage.saveRefreshedTokens(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );
    updateTokens(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );
  }
}

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);

/// The active server profile's id, or null while signed out.
final activeProfileIdProvider = Provider<String?>((ref) {
  final session = ref.watch(sessionControllerProvider);
  return session is SessionAuthenticated ? session.profileId : null;
});
