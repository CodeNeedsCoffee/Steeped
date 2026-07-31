import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/socket_service.dart';
import '../auth/state/session_controller.dart';
import '../auth/state/session_state.dart';

/// Placeholder for the post-login home shell (library browsing, Phase 4;
/// mini-player, Phase 5). Shows the logged-in user, live socket connection
/// status, and a logout action for now — just enough to prove the Phase 3
/// session + websocket flow actually works end to end.
class HomeShellScreen extends ConsumerWidget {
  const HomeShellScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    final socketStatus = ref.watch(socketServiceProvider);
    final username = switch (session) {
      SessionAuthenticated(:final user) => user.username,
      _ => null,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Steeped'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(child: _ConnectionBadge(status: socketStatus)),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () =>
                ref.read(sessionControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: Center(
        child: Text(
          username != null
              ? 'Signed in as $username\n\nLibrary browsing — coming in Phase 4'
              : 'Home — coming in Phases 4 & 5',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _ConnectionBadge extends StatelessWidget {
  const _ConnectionBadge({required this.status});

  final SocketConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      SocketConnectionStatus.authenticated => (Colors.greenAccent, 'Live'),
      SocketConnectionStatus.connected => (Colors.amber, 'Connecting'),
      SocketConnectionStatus.connecting => (Colors.amber, 'Connecting'),
      SocketConnectionStatus.authFailed => (Colors.redAccent, 'Auth failed'),
      SocketConnectionStatus.disconnected => (Colors.grey, 'Offline'),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 10, color: color),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
