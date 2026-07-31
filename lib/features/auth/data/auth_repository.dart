import 'package:dio/dio.dart';

import '../../../models/login_result.dart';
import '../../../models/server_status.dart';

/// Talks to the pre-auth Audiobookshelf endpoints (`/status`, `/login`,
/// `/auth/refresh`). Deliberately does *not* use the shared, interceptor-
/// attached `dioProvider` — a wrong-password 401 from `/login` must never
/// be mistaken for an expired-session 401 by [AuthInterceptor].
class AuthRepository {
  const AuthRepository();

  /// Normalizes user input into a base URL: trims whitespace, strips a
  /// trailing slash, and defaults to `https://` if no scheme was given.
  static String normalizeServerUrl(String input) {
    var url = input.trim();
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    return url;
  }

  Dio _clientFor(String serverUrl) {
    return Dio(
      BaseOptions(
        baseUrl: serverUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
  }

  Future<ServerStatus> checkStatus(String serverUrl) async {
    final response = await _clientFor(
      serverUrl,
    ).get<Map<String, dynamic>>('/status');
    return ServerStatus.fromJson(response.data ?? const {});
  }

  Future<LoginResult> login({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    final response = await _clientFor(serverUrl).post<Map<String, dynamic>>(
      '/login',
      data: {'username': username, 'password': password},
      options: Options(headers: {'x-return-tokens': 'true'}),
    );
    return LoginResult.fromJson(response.data ?? const {});
  }

  /// Proactively validates + refreshes a persisted session on app startup
  /// (as opposed to [AuthInterceptor]'s reactive refresh on a 401 from some
  /// other call). Only meaningful for 2.26.0+ servers — legacy-token
  /// sessions have no refresh endpoint and are trusted until a 401 occurs.
  Future<LoginResult> refresh({
    required String serverUrl,
    required String refreshToken,
  }) async {
    final response = await _clientFor(serverUrl).post<Map<String, dynamic>>(
      '/auth/refresh',
      options: Options(headers: {'x-refresh-token': refreshToken}),
    );
    return LoginResult.fromJson(response.data ?? const {});
  }
}
