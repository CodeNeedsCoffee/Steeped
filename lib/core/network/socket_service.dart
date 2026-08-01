import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;

import '../../features/auth/state/session_controller.dart';
import '../../features/auth/state/session_state.dart';
import '../logging/log_repository.dart';
import '../storage/session_storage.dart';

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
      final serverUrl = switch (next) {
        SessionAuthenticated(:final serverUrl) => serverUrl,
        _ => null,
      };
      if (serverUrl != null) {
        unawaited(_connect(serverUrl));
      } else {
        _disconnect();
      }
    }, fireImmediately: true);
  }

  final Ref _ref;
  socket_io.Socket? _socket;
  String? _connectedServerUrl;
  int _authRetryCount = 0;

  /// Bug found 2026-08-01 (reported by evan: "auth fails randomly"): the
  /// access token is a short-lived JWT (see `AuthUser.accessToken`'s doc
  /// comment) that `AuthInterceptor` already refreshes transparently on a
  /// REST 401 — but only in secure storage, never back into this class.
  /// The old version of this method took `token` as a parameter and
  /// captured it in the `onConnect` closure below; that value never
  /// changed again for the socket's lifetime. That was invisible on the
  /// *first* connect, but `socket_io_client`'s own Manager reconnects
  /// automatically after any transport-level drop (a wifi/cellular
  /// handoff, doze, a brief signal loss — exactly the kind of thing that
  /// happens over the course of a real day, hence "randomly") *without*
  /// ever calling back into this method — it just re-fires the same
  /// `onConnect` listener, re-sending the same now-stale token forever.
  /// Fixed by re-reading the token from storage (the freshest copy,
  /// updated independently by `AuthInterceptor`) at the moment of *every*
  /// connect, including ones `socket_io_client` triggers on its own.
  Future<void> _connect(String serverUrl) async {
    // Already connected/connecting to this server — a token rotation
    // alone doesn't need a full reconnect (see the onConnect re-fetch
    // below); auth_failed is what handles a genuinely stale token.
    if (_socket != null && _connectedServerUrl == serverUrl) return;
    _disconnect();

    final storage = _ref.read(sessionStorageProvider);
    final token = await storage.readEffectiveToken();
    if (token == null) return;

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
      unawaited(_emitFreshAuth(socket));
    });
    socket.on('init', (_) {
      _authRetryCount = 0;
      state = SocketConnectionStatus.authenticated;
    });
    socket.on('auth_failed', (_) {
      state = SocketConnectionStatus.authFailed;
      unawaited(
        _ref
            .read(logRepositoryProvider)
            .log(
              'warning',
              'socket',
              'Socket auth failed — refreshing token and retrying',
            ),
      );
      unawaited(_retryAfterAuthFailure(serverUrl));
    });
    socket.onDisconnect((_) => state = SocketConnectionStatus.disconnected);
    socket.onConnectError((_) => state = SocketConnectionStatus.disconnected);

    socket.connect();
    _socket = socket;
    _connectedServerUrl = serverUrl;
  }

  /// Always reads storage fresh rather than closing over a token value —
  /// this is what makes every reconnect (ours or `socket_io_client`'s own
  /// automatic one) send current credentials instead of a stale snapshot.
  Future<void> _emitFreshAuth(socket_io.Socket socket) async {
    final token = await _ref.read(sessionStorageProvider).readEffectiveToken();
    if (token != null) socket.emit('auth', token);
  }

  /// A real `auth_failed` means the access token has actually expired —
  /// re-reading storage alone won't help unless something else already
  /// refreshed it, so this forces the same `/auth/refresh` call
  /// `AuthInterceptor`/`SessionController` bootstrap already use, bounded
  /// to 3 attempts with backoff so a genuinely revoked refresh token (or a
  /// legacy-token server, which has no refresh endpoint at all) can't spin
  /// forever.
  Future<void> _retryAfterAuthFailure(String serverUrl) async {
    if (_authRetryCount >= 3) return;
    _authRetryCount++;
    _disconnect();

    final storage = _ref.read(sessionStorageProvider);
    final refreshToken = await storage.readRefreshToken();
    if (refreshToken != null) {
      try {
        final result = await _ref
            .read(authRepositoryProvider)
            .refresh(serverUrl: serverUrl, refreshToken: refreshToken);
        await storage.saveRefreshedTokens(
          accessToken: result.user.accessToken,
          refreshToken: result.user.refreshToken ?? refreshToken,
        );
      } catch (_) {
        // Refresh itself failed, or this is a legacy-token server with no
        // refresh endpoint — fall through and just retry with whatever's
        // already in storage rather than giving up immediately.
      }
    }

    await Future.delayed(Duration(seconds: 2 * _authRetryCount));
    final session = _ref.read(sessionControllerProvider);
    if (session is SessionAuthenticated) await _connect(serverUrl);
  }

  void _disconnect() {
    _socket?.dispose();
    _socket = null;
    _connectedServerUrl = null;
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
