import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/state/session_expired_signal.dart';
import '../storage/session_storage.dart';
import 'auth_interceptor.dart';

/// Shared [Dio] instance for authenticated calls to a user's Audiobookshelf
/// server. `baseUrl` is set once a server is connected (see
/// `SessionController`); the [AuthInterceptor] attaches the bearer token and
/// handles token refresh on 401.
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
  return dio;
});
