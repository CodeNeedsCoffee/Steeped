import 'package:dio/dio.dart';

import '../storage/session_storage.dart';

/// Attaches the bearer token to every request, and on a 401 makes a single
/// attempt to refresh via `POST /auth/refresh` (`x-refresh-token` header)
/// before retrying the original request once. Mirrors the reference app's
/// `plugins/nativeHttp.js` behavior — no silent retry loop beyond one
/// refresh+retry; failure calls [onSessionExpired] so the app can force a
/// re-login.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required this.sessionStorage,
    required this.onSessionExpired,
    required this.onTokensRefreshed,
  });

  final SessionStorage sessionStorage;
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

    final refreshToken = await sessionStorage.readRefreshToken();
    if (refreshToken == null) {
      await onSessionExpired();
      handler.next(err);
      return;
    }

    try {
      final refreshDio = Dio(
        BaseOptions(baseUrl: err.requestOptions.baseUrl),
      );
      final response = await refreshDio.post<Map<String, dynamic>>(
        _refreshPath,
        options: Options(headers: {'x-refresh-token': refreshToken}),
      );
      final userJson = response.data?['user'] as Map<String, dynamic>?;
      final newAccessToken = userJson?['accessToken'] as String?;
      final newRefreshToken = userJson?['refreshToken'] as String?;
      if (newAccessToken == null) {
        await onSessionExpired();
        handler.next(err);
        return;
      }

      await sessionStorage.saveRefreshedTokens(
        accessToken: newAccessToken,
        refreshToken: newRefreshToken ?? refreshToken,
      );
      onTokensRefreshed(
        accessToken: newAccessToken,
        refreshToken: newRefreshToken ?? refreshToken,
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
