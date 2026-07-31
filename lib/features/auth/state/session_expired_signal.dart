import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Fired by [AuthInterceptor] when a token refresh fails on some unrelated
/// API call and the session must be force-logged-out. [SessionController]
/// listens to this so it can react even though it isn't the one that made
/// the failing request.
class SessionExpiredSignal extends StateNotifier<int> {
  SessionExpiredSignal() : super(0);
  void fire() => state++;
}

final sessionExpiredSignalProvider =
    StateNotifierProvider<SessionExpiredSignal, int>(
      (ref) => SessionExpiredSignal(),
    );
