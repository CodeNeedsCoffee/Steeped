import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/data/server_profile_repository.dart';
import '../auth/masked_server_address.dart';
import '../auth/state/profile_switcher.dart';
import '../auth/state/session_controller.dart';
import '../auth/state/session_state.dart';
import '../../l10n/l10n.dart';

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
      appBar: AppBar(title: Text(context.l10n.account)),
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
            child: Text(
              user.username,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          if (user.email.isNotEmpty)
            Center(
              child: Text(
                user.email,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          const SizedBox(height: 8),
          Center(child: Chip(label: Text(user.type))),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.dns_outlined),
            title: Text(context.l10n.server),
            subtitle: MaskedServerAddress(session.serverUrl),
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: Text(context.l10n.downloadsAllowed),
            trailing: Icon(
              user.permissions.download ? Icons.check : Icons.close,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.upload_outlined),
            title: Text(context.l10n.uploadsAllowed),
            trailing: Icon(user.permissions.upload ? Icons.check : Icons.close),
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: Text(context.l10n.updatesAllowed),
            trailing: Icon(user.permissions.update ? Icons.check : Icons.close),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: Text(context.l10n.deletesAllowed),
            trailing: Icon(user.permissions.delete ? Icons.check : Icons.close),
          ),
          const SizedBox(height: 24),
          _AccountsSection(activeProfileId: session.profileId),
          const SizedBox(height: 24),
          // Hidden for guests: the server rejects their password change with
          // a 403 (`MeController.updatePassword`), so offering it would only
          // ever lead to a dead end.
          if (user.type != 'guest')
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: Text(context.l10n.changePassword),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/account/password'),
            ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: () =>
                ref.read(sessionControllerProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
            label: Text(context.l10n.logOut),
          ),
        ],
      ),
    );
  }
}

/// QOL_PLAN E2.4: every saved server/account, with switch and remove, plus
/// the entry point for adding another.
class _AccountsSection extends ConsumerWidget {
  const _AccountsSection({required this.activeProfileId});

  final String activeProfileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(serverProfilesProvider).valueOrNull ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.accounts,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        for (final p in profiles)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              p.id == activeProfileId
                  ? Icons.check_circle
                  : Icons.person_outline,
              color: p.id == activeProfileId
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            title: Text(p.username),
            subtitle: MaskedServerAddress(
              hostOfServerUrl(p.serverUrl),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            onTap: p.id == activeProfileId
                ? null
                : () => confirmAndSwitchProfile(context, ref, p),
            trailing: PopupMenuButton<String>(
              tooltip: context.l10n.more,
              onSelected: (v) {
                if (v == 'switch') confirmAndSwitchProfile(context, ref, p);
                if (v == 'remove') confirmAndRemoveProfile(context, ref, p);
              },
              itemBuilder: (ctx) => [
                if (p.id != activeProfileId)
                  PopupMenuItem(
                    value: 'switch',
                    child: Text(ctx.l10n.switchAction),
                  ),
                PopupMenuItem(value: 'remove', child: Text(ctx.l10n.remove)),
              ],
            ),
          ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.add),
          title: Text(context.l10n.addServerOrAccount),
          onTap: () => context.push('/add-server'),
        ),
      ],
    );
  }
}
