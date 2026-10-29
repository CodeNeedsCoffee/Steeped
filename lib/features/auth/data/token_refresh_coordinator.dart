import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/session_storage.dart';
import '../../../models/auth_user.dart';
import 'auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => const AuthRepository(),
);

/// Bug fix 2026-09-04: `AuthInterceptor` (on a REST 401), `SocketService`
/// (on a socket `auth_failed`), and `SessionController` (on cold-start
/// bootstrap) each independently called `POST /auth/refresh` and
/// independently wrote the result to `SessionStorage`, with no coordination
/// between them. Two of them firing close together (e.g. a socket reconnect
/// racing a background REST call) sent the *same* stale refresh token to
/// the server twice; since the server rotates/invalidates the refresh token
/// on use, the loser got a genuine 401 back even though the session was
/// still alive — and for `AuthInterceptor` that 401 unconditionally cleared
/// the whole session, logging the user out from under the winning refresh.
/// This coordinator makes all three call sites share one in-flight refresh
/// (and one storage write) instead of racing.
class TokenRefreshCoordinator {
  TokenRefreshCoordinator({
    required this.authRepository,
    required this.sessionStorage,
  });

  final AuthRepository authRepository;
  final SessionStorage sessionStorage;

  /// One in-flight refresh per profile: two accounts never share a refresh
  /// token, and one account's refresh never blocks another's.
  final Map<String, Future<AuthUser>> _inFlight = {};

  /// Refreshes the session and persists the result, coalescing concurrent
  /// callers into a single network call. Every caller in flight when a
  /// refresh starts shares its exact outcome — success or failure — so no
  /// two callers ever race the server with the same soon-to-be-stale
  /// refresh token.
  ///
  /// [profileId] defaults to the active profile *at call time*; the result is
  /// written back to that same profile even if the user switches accounts
  /// before the network call returns.
  Future<AuthUser> refresh({
    required String serverUrl,
    String? profileId,
  }) async {
    final id = profileId ?? await sessionStorage.readActiveProfileId();
    if (id == null) throw StateError('No active server profile');
    return _inFlight[id] ??= _doRefresh(
      serverUrl,
      id,
    ).whenComplete(() {
      _inFlight.remove(id);
    });
  }

  Future<AuthUser> _doRefresh(String serverUrl, String profileId) async {
    final refreshToken = await sessionStorage.readRefreshToken(
      profileId: profileId,
    );
    if (refreshToken == null) {
      throw StateError('No refresh token available');
    }
    final result = await authRepository.refresh(
      serverUrl: serverUrl,
      refreshToken: refreshToken,
    );
    await sessionStorage.saveRefreshedTokens(
      accessToken: result.user.accessToken,
      refreshToken: result.user.refreshToken ?? refreshToken,
      profileId: profileId,
    );
    return result.user;
  }
}

final tokenRefreshCoordinatorProvider = Provider<TokenRefreshCoordinator>(
  (ref) => TokenRefreshCoordinator(
    authRepository: ref.watch(authRepositoryProvider),
    sessionStorage: ref.watch(sessionStorageProvider),
  ),
);
