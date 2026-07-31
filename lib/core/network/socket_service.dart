import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;

import '../../features/auth/state/session_controller.dart';
import '../../features/auth/state/session_state.dart';

/// PLAN.md Phase 3.6. The Audiobookshelf server speaks socket.io v4, not a
/// raw websocket (see the `socket_io_client` correction to Phase 0.4).
/// Connects to `<host>/socket.io`, then authenticates by emitting `auth`
/// with the bearer token after `connect` fires — matching
/// `~/Code/audiobookshelf-app/plugins/server.js`.
enum SocketConnectionStatus {
  disconnected,
  connecting,
  connected,
  authenticated,
  authFailed,
}

class SocketService extends StateNotifier<SocketConnectionStatus> {
  SocketService(this._ref) : super(SocketConnectionStatus.disconnected) {
    _ref.listen<SessionState>(sessionControllerProvider, (previous, next) {
      final token = switch (next) {
        SessionAuthenticated(:final user) => user.effectiveToken,
        _ => null,
      };
      final serverUrl = switch (next) {
        SessionAuthenticated(:final serverUrl) => serverUrl,
        _ => null,
      };
      if (token != null && serverUrl != null) {
        _connect(serverUrl, token);
      } else {
        _disconnect();
      }
    }, fireImmediately: true);
  }

  final Ref _ref;
  socket_io.Socket? _socket;

  void _connect(String serverUrl, String token) {
    if (_socket != null) return; // already connecting/connected

    final uri = Uri.parse(serverUrl);
    final host =
        '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
    final basePath = (uri.path.isEmpty || uri.path == '/') ? '' : uri.path;

    state = SocketConnectionStatus.connecting;

    final socket = socket_io.io(
      host,
      socket_io.OptionBuilder()
          .setPath('$basePath/socket.io')
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    socket.onConnect((_) {
      state = SocketConnectionStatus.connected;
      socket.emit('auth', token);
    });
    socket.on('init', (_) => state = SocketConnectionStatus.authenticated);
    socket.on('auth_failed', (_) => state = SocketConnectionStatus.authFailed);
    socket.onDisconnect((_) => state = SocketConnectionStatus.disconnected);
    socket.onConnectError((_) => state = SocketConnectionStatus.disconnected);

    socket.connect();
    _socket = socket;
  }

  void _disconnect() {
    _socket?.dispose();
    _socket = null;
    state = SocketConnectionStatus.disconnected;
  }

  @override
  void dispose() {
    _disconnect();
    super.dispose();
  }
}

final socketServiceProvider =
    StateNotifierProvider<SocketService, SocketConnectionStatus>(
      (ref) => SocketService(ref),
    );
