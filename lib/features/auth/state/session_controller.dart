import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/log_repository.dart';
import '../../../core/storage/session_storage.dart';
import '../../../models/server_status.dart';
import '../data/auth_repository.dart';
import 'session_expired_signal.dart';
import 'session_state.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => const AuthRepository(),
);

class SessionController extends Notifier<SessionState> {
  late final AuthRepository _repository;
  late final SessionStorage _storage;

  @override
  SessionState build() {
    _repository = ref.watch(authRepositoryProvider);
    _storage = ref.watch(sessionStorageProvider);

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
    final serverUrl = await _storage.readServerUrl();
    if (serverUrl == null) {
      state = const SessionUnauthenticated();
      return;
    }

    final refreshToken = await _storage.readRefreshToken();
    if (refreshToken != null) {
      // 2.26.0+ server: proactively refresh to confirm the session is
      // still valid and get current user/permissions data.
      try {
        final result = await _repository.refresh(
          serverUrl: serverUrl,
          refreshToken: refreshToken,
        );
        await _storage.save(serverUrl: serverUrl, user: result.user);
        state = SessionAuthenticated(serverUrl: serverUrl, user: result.user);
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
          await _storage.clear();
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
        final cachedUser = await _storage.readCachedUser();
        if (cachedUser?.effectiveToken != null) {
          state = SessionAuthenticated(
            serverUrl: serverUrl,
            user: cachedUser!,
          );
        } else {
          state = const SessionUnauthenticated();
        }
      }
      return;
    }

    // Legacy-token server (< 2.26.0): no refresh endpoint exists, so trust
    // the cached session until a 401 actually occurs.
    final cachedUser = await _storage.readCachedUser();
    if (cachedUser?.effectiveToken != null) {
      state = SessionAuthenticated(serverUrl: serverUrl, user: cachedUser!);
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

  Future<void> login({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    final result = await _repository.login(
      serverUrl: serverUrl,
      username: username,
      password: password,
    );
    await _storage.save(serverUrl: serverUrl, user: result.user);
    state = SessionAuthenticated(serverUrl: serverUrl, user: result.user);
  }

  Future<void> logout() async {
    await _storage.clear();
    state = const SessionUnauthenticated();
  }
}

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);
