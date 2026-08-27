import 'package:dio/dio.dart';

/// Retries [action] up to [maxAttempts] times, but only for connection-level
/// failures (DNS lookup, timeout, refused connection) -- never for a real
/// server response like a 401/404/500, where retrying would just repeat the
/// same failure. Linear backoff (`2s * attempt`) mirrors the existing
/// bounded-retry idiom in `SocketService._retryAfterAuthFailure`.
///
/// Added 2026-08-26 after a real cold-start "Failed host lookup" on a
/// physical device that cleared on a manual retry a few seconds later --
/// this makes that class of transient blip retry itself instead of leaving
/// the user stuck on an error screen for what was often just a one-off.
Future<T> withNetworkRetry<T>(
  Future<T> Function() action, {
  int maxAttempts = 3,
}) async {
  var attempt = 0;
  while (true) {
    attempt++;
    try {
      return await action();
    } on DioException catch (e) {
      final isTransient = switch (e.type) {
        DioExceptionType.connectionError ||
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout => true,
        _ => false,
      };
      if (!isTransient || attempt >= maxAttempts) rethrow;
      await Future.delayed(Duration(seconds: 2 * attempt));
    }
  }
}
