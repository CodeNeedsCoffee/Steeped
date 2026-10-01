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
  bool _isDisposed = false;

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
      if (_isDisposed) return;
      state = SocketConnectionStatus.connected;
      unawaited(_emitFreshAuth(socket));
    });
    socket.on('init', (_) {
      if (_isDisposed) return;
      state = SocketConnectionStatus.authenticated;
    });
    socket.on('auth_failed', (_) {
      if (_isDisposed) return;
      state = SocketConnectionStatus.authFailed;
      // Bug fix 2026-09-30: this used to actively drive its own
      // /auth/refresh-and-retry loop (bounded to 3 attempts) right here.
      // That meant a refresh could fire from an arbitrary background
      // moment — a socket reconnect after a network blip, screen lock, app
      // switch — with nothing tying it to real foreground activity, making
      // it far more exposed to iOS suspending the app mid-request (the
      // server had already rotated the refresh token server-side; the
      // client never persisted the new one; the *old* one — now dead — was
      // all that was left in Keychain for the next cold start). The
      // reference app (~/Code/audiobookshelf-app plugins/server.js
      // `onAuthFailed`) does none of this: it just flags itself
      // unauthenticated and leaves refreshing entirely to a real REST call
      // hitting a genuine 401 (nativeHttp.js), which then re-authenticates
      // the socket as a side effect via `updateTokens`. Mirrored here:
      // SessionController.updateTokens calls reauthenticateIfNeeded below
      // whenever that reactive refresh succeeds.
      unawaited(
        _ref
            .read(logRepositoryProvider)
            .log('warning', 'socket', 'Socket auth failed'),
      );
    });
    socket.onDisconnect((_) {
      // `dispose()` -> `_disconnect()` -> `socket.dispose()` triggers this
      // same `onclose` event synchronously, as part of the *provider's own*
      // disposal — by then `_ref` may already belong to a torn-down
      // ProviderContainer, and reading from it throws "container already
      // disposed" (found via integration_test/app_test.dart teardown).
      if (_isDisposed) return;
      state = SocketConnectionStatus.disconnected;
      // Debugging note (2026-08-03): only `auth_failed` was logged before —
      // an ordinary disconnect (wifi handoff, doze, server restart) gave no
      // trace at all, making it hard to correlate a socket drop with a
      // playback stall investigated around the same time.
      unawaited(
        _ref
            .read(logRepositoryProvider)
            .log('warning', 'socket', 'Socket disconnected'),
      );
    });
    socket.onConnectError((error) {
      if (_isDisposed) return;
      state = SocketConnectionStatus.disconnected;
      unawaited(
        _ref
            .read(logRepositoryProvider)
            .log('warning', 'socket', 'Socket connect error: $error'),
      );
    });

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

  /// Called by [SessionController.updateTokens] after any refresh succeeds
  /// elsewhere — `AuthInterceptor`'s reactive REST-401 refresh, or the
  /// cold-start bootstrap refresh — mirroring the reference app's
  /// `nativeHttp.js` `updateTokens()` calling `$socket.sendAuthenticate()`
  /// when the socket is connected but not authenticated. Without this,
  /// nothing pokes an existing `authFailed` socket to retry with the
  /// freshly rotated token: `socket_io_client` only auto-reconnects on a
  /// transport-level drop, not on this app-level event — the underlying
  /// connection is still up, just unauthenticated.
  void reauthenticateIfNeeded() {
    final socket = _socket;
    if (socket == null || state != SocketConnectionStatus.authFailed) return;
    unawaited(_emitFreshAuth(socket));
  }

  void _disconnect() {
    _socket?.dispose();
    _socket = null;
    _connectedServerUrl = null;
    state = SocketConnectionStatus.disconnected;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _disconnect();
    super.dispose();
  }
}

final socketServiceProvider =
    StateNotifierProvider<SocketService, SocketConnectionStatus>(
      (ref) => SocketService(ref),
    );
