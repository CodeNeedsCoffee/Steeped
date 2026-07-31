import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shared [Dio] instance for talking to a user's Audiobookshelf server.
///
/// No base URL or auth interceptor yet — Phase 3 (Server Connection &
/// Authentication) configures those once a server is connected.
final dioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );
});
