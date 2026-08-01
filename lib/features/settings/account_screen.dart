import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/state/session_controller.dart';
import '../auth/state/session_state.dart';

/// PLAN.md Phase 9.2: user info, logout. "Switch server/user" stays out of
/// scope — deliberately deferred with the multi-server switcher itself
/// (PLAN.md Phase 3.3, a single-session app for now).
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    if (session is! SessionAuthenticated) {
      return const Scaffold(body: SizedBox.shrink());
    }
    final user = session.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: CircleAvatar(
              radius: 40,
              child: Text(
                user.username.isEmpty ? '?' : user.username[0].toUpperCase(),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(user.username, style: Theme.of(context).textTheme.titleLarge),
          ),
          if (user.email.isNotEmpty)
            Center(
              child: Text(user.email, style: Theme.of(context).textTheme.bodyMedium),
            ),
          const SizedBox(height: 8),
          Center(child: Chip(label: Text(user.type))),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.dns_outlined),
            title: const Text('Server'),
            subtitle: Text(session.serverUrl),
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Downloads allowed'),
            trailing: Icon(
              user.permissions.download ? Icons.check : Icons.close,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.upload_outlined),
            title: const Text('Uploads allowed'),
            trailing: Icon(
              user.permissions.upload ? Icons.check : Icons.close,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.tonalIcon(
            onPressed: () =>
                ref.read(sessionControllerProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
            label: const Text('Log Out'),
          ),
        ],
      ),
    );
  }
}
