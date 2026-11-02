import 'package:dio/dio.dart';

import '../../../models/login_result.dart';
import '../../../models/server_status.dart';

/// Talks to the pre-auth Audiobookshelf endpoints (`/status`, `/login`,
/// `/auth/refresh`). Deliberately does *not* use the shared, interceptor-
/// attached `dioProvider` — a wrong-password 401 from `/login` must never
/// be mistaken for an expired-session 401 by [AuthInterceptor].
class AuthRepository {
  const AuthRepository();

  static final _scheme = RegExp(r'^(https?):/{0,2}', caseSensitive: false);

  /// True if [input] starts with `http:` or `https:` (any case, with or
  /// without the slashes), i.e. the user chose a scheme.
  static bool hasScheme(String input) => _scheme.hasMatch(input.trim());

  /// Normalizes user input into a base URL: trims whitespace, strips
  /// trailing slashes, and writes a typed `http://`/`https://` in canonical
  /// form (any case, slashes optional). Without a scheme it defaults to
  /// `https://`; `SessionController.checkServer` may then fall back to `http://`.
  static String normalizeServerUrl(
    String input, {
    String defaultScheme = 'https',
  }) {
    var url = input.trim();
    final match = _scheme.firstMatch(url);
    final scheme = match?.group(1)?.toLowerCase() ?? defaultScheme;
    if (match != null) url = url.substring(match.end);
    url = url.replaceAll(RegExp(r'/+$'), '');
    return '$scheme://$url';
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
