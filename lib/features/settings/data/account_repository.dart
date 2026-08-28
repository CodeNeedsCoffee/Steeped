import 'package:dio/dio.dart';

/// Authenticated account operations against `/api/me`. Unlike
/// [AuthRepository] — which deliberately builds its own bare [Dio] so a
/// wrong-password 401 from `/login` can't be mistaken for an expired
/// session — these calls need the real bearer token, so they go through the
/// shared interceptor-attached `dioProvider`.
class AccountRepository {
  AccountRepository(this._dio);

  final Dio _dio;

  /// `PATCH /api/me/password` (Audiobookshelf `MeController.updatePassword`).
  ///
  /// A successful change invalidates the user's *other* JWT sessions server
  /// side. The server only hands back replacement tokens for this session
  /// when the request carries `x-refresh-token` — without it the response is
  /// a bare 200 and this device's session dies on its next request. So the
  /// header goes out whenever a refresh token exists, and the caller must
  /// persist whatever comes back.
  ///
  /// Returns nulls on a pre-2.26.0 server: those have no JWT sessions to
  /// rotate, and the static `legacyToken` survives a password change.
  Future<({String? accessToken, String? refreshToken})> changePassword({
    required String currentPassword,
    required String newPassword,
    required String? refreshToken,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/api/me/password',
      data: {'password': currentPassword, 'newPassword': newPassword},
      options: Options(headers: {'x-refresh-token': ?refreshToken}),
    );
    final user = response.data?['user'] as Map<String, dynamic>?;
    return (
      accessToken: user?['accessToken'] as String?,
      refreshToken: user?['refreshToken'] as String?,
    );
  }
}
