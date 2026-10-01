import 'package:dio/dio.dart';

import '../../features/auth/data/token_refresh_coordinator.dart';
import '../../models/auth_user.dart';
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

    final AuthUser user;
    try {
      // Goes through TokenRefreshCoordinator (shared with SocketService and
      // SessionController's bootstrap) rather than posting to /auth/refresh
      // directly, so a REST 401 racing a socket reconnect never sends the
      // same soon-to-be-stale refresh token to the server twice — see
      // TokenRefreshCoordinator's doc comment.
      user = await tokenRefreshCoordinator.refresh(
        serverUrl: err.requestOptions.baseUrl,
      );
    } catch (e) {
      // Bug fix 2026-09-30: this used to treat *any* failure here — a
      // genuine server rejection, but equally a plain network timeout mid-
      // refresh — as proof the session was dead, and unconditionally wiped
      // secure storage via onSessionExpired(). A refresh call that never
      // reached the server (or whose response never arrived) says nothing
      // about whether the stored refresh token is actually still valid, so
      // that path was destroying perfectly good sessions on nothing more
      // than a bad-signal moment. Mirrors SessionController._bootstrap's
      // existing DioExceptionType.badResponse-only distinction, and
      // AudioBooth's CredentialsActor.handleError (~/Code/AudioBooth):
      // only a definitive rejection — the refresh endpoint itself
      // responding 401/403, or no refresh token existing at all — means
      // the session is actually gone. Anything else is transient; leave
      // the stored tokens alone and let the next call try again.
      final isDefinitiveRejection =
          e is StateError ||
          (e is DioException && e.type == DioExceptionType.badResponse);
      if (isDefinitiveRejection) {
        await onSessionExpired();
      }
      handler.next(err);
      return;
    }

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

    try {
      // A failure here is the *original* request failing again for reasons
      // unrelated to auth (the refresh above already succeeded and is
      // persisted) — propagate it as-is rather than treating it as a
      // session-expiry signal too.
      final retryOptions = err.requestOptions
        ..headers['Authorization'] = 'Bearer $newAccessToken';
      final retryDio = Dio(BaseOptions(baseUrl: err.requestOptions.baseUrl));
      final retryResponse = await retryDio.fetch(retryOptions);
      handler.resolve(retryResponse);
    } catch (_) {
      handler.next(err);
    }
  }
}
