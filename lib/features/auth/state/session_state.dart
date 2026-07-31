import '../../../models/auth_user.dart';

/// Where the app is at with respect to a server connection + login.
/// `sealed` so router redirects and UI can exhaustively switch on it.
sealed class SessionState {
  const SessionState();
}

/// Startup only: checking secure storage (and, for 2.26.0+ servers,
/// refreshing the token) before deciding where to route the user.
class SessionBootstrapping extends SessionState {
  const SessionBootstrapping();
}

class SessionUnauthenticated extends SessionState {
  const SessionUnauthenticated();
}

class SessionAuthenticated extends SessionState {
  const SessionAuthenticated({required this.serverUrl, required this.user});

  final String serverUrl;
  final AuthUser user;
}
