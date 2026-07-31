import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
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
        ref.read(dioProvider).options.baseUrl = serverUrl;
        state = SessionAuthenticated(serverUrl: serverUrl, user: result.user);
      } catch (_) {
        await _storage.clear();
        state = const SessionUnauthenticated();
      }
      return;
    }

    // Legacy-token server (< 2.26.0): no refresh endpoint exists, so trust
    // the cached session until a 401 actually occurs.
    final cachedUser = await _storage.readCachedUser();
    if (cachedUser?.effectiveToken != null) {
      ref.read(dioProvider).options.baseUrl = serverUrl;
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
    ref.read(dioProvider).options.baseUrl = serverUrl;
    state = SessionAuthenticated(serverUrl: serverUrl, user: result.user);
  }

  Future<void> logout() async {
    await _storage.clear();
    state = const SessionUnauthenticated();
  }
}

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);
