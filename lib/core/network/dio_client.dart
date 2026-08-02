import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/state/session_controller.dart';
import '../../features/auth/state/session_expired_signal.dart';
import '../../features/auth/state/session_state.dart';
import '../storage/session_storage.dart';
import 'auth_interceptor.dart';

/// Shared [Dio] instance for authenticated calls to a user's Audiobookshelf
/// server. `baseUrl` reactively tracks [sessionControllerProvider] rather
/// than being mutated imperatively from `SessionController` — see the
/// 2026-08-02 bug fix note below for why that distinction matters. The
/// [AuthInterceptor] attaches the bearer token and handles token refresh
/// on 401.
///
/// Not used for the pre-auth server-status/login calls — those construct
/// their own short-lived [Dio] so a bad-password 401 from `/login` itself
/// can never be mistaken for an expired-session 401 on this instance.
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );
  dio.interceptors.add(
    AuthInterceptor(
      sessionStorage: ref.watch(sessionStorageProvider),
      onSessionExpired: () async {
        await ref.read(sessionStorageProvider).clear();
        ref.read(sessionExpiredSignalProvider.notifier).fire();
      },
    ),
  );
  // Bug found 2026-08-02 (reported by evan: "Failed to load libraries" /
  // "No host specified in URI /api/libraries", with the socket "Live"
  // badge showing green at the same time). Previously `baseUrl` was set by
  // `SessionController` imperatively mutating this same long-lived Dio
  // instance's `.options.baseUrl` after the fact — invisible to Riverpod's
  // dependency graph, since the provider's *output reference* never
  // changed. A plain (non-family) FutureProvider like `librariesProvider`
  // only ever computes once and caches its result, including a failure;
  // nothing was watching a value that actually changed to trigger a
  // recompute. If `librariesProvider` was read even once while `baseUrl`
  // was still its Dio default (empty string) -- plausible on a background
  // resume where the socket picks up the correct URL fresh from each auth
  // event (see SocketService), but nothing forced the cached library fetch
  // to retry -- it stayed permanently broken until a full app restart.
  // Watching session state here instead means any consumer that
  // transitively depends on `dioProvider` (`libraryRepositoryProvider` ->
  // `librariesProvider`, etc.) automatically recomputes whenever the
  // session (and therefore the correct `baseUrl`) actually changes.
  final session = ref.watch(sessionControllerProvider);
  if (session is SessionAuthenticated) {
    dio.options.baseUrl = session.serverUrl;
  }
  return dio;
});
