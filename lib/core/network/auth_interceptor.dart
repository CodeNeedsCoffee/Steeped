import 'package:dio/dio.dart';

import '../../features/auth/data/token_refresh_coordinator.dart';
import '../storage/session_storage.dart';

/// Attaches the bearer token to every request, and on a 401 makes a single
/// attempt to refresh via [TokenRefreshCoordinator] before retrying the
/// original request once. Mirrors the reference app's `plugins/nativeHttp.js`
/// behavior — no silent retry loop beyond one refresh+retry; failure calls
/// [onSessionExpired] so the app can force a re-login.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required this.sessionStorage,
    required this.tokenRefreshCoordinator,
    required this.onSessionExpired,
    required this.onTokensRefreshed,
  });

  final SessionStorage sessionStorage;
  final TokenRefreshCoordinator tokenRefreshCoordinator;
  final Future<void> Function() onSessionExpired;

  /// Bug fix 2026-08-03: a refresh here previously only reached secure
  /// storage — the in-memory session (and anything reading its token
  /// directly, like PlaybackController's stream URL builder) never found
  /// out, so it kept using the stale pre-refresh token until the next app
  /// restart. See SessionController.updateTokens.
  final void Function({required String? accessToken, required String? refreshToken})
  onTokensRefreshed;

  static const _refreshPath = '/auth/refresh';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await sessionStorage.readEffectiveToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final isRefreshCall = err.requestOptions.path.contains(_refreshPath);
    if (err.response?.statusCode != 401 || isRefreshCall) {
      handler.next(err);
      return;
    }

    try {
      // Goes through TokenRefreshCoordinator (shared with SocketService and
      // SessionController's bootstrap) rather than posting to /auth/refresh
      // directly, so a REST 401 racing a socket reconnect never sends the
      // same soon-to-be-stale refresh token to the server twice — see
      // TokenRefreshCoordinator's doc comment.
      final user = await tokenRefreshCoordinator.refresh(
        serverUrl: err.requestOptions.baseUrl,
      );
      final newAccessToken = user.accessToken;
      if (newAccessToken == null) {
        await onSessionExpired();
        handler.next(err);
        return;
      }

      onTokensRefreshed(
        accessToken: newAccessToken,
        refreshToken: user.refreshToken,
      );

      final retryOptions = err.requestOptions
        ..headers['Authorization'] = 'Bearer $newAccessToken';
      final retryDio = Dio(BaseOptions(baseUrl: err.requestOptions.baseUrl));
      final retryResponse = await retryDio.fetch(retryOptions);
      handler.resolve(retryResponse);
    } catch (_) {
      await onSessionExpired();
      handler.next(err);
    }
  }
}
