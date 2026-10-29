import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n.dart';
import 'data/server_profile_repository.dart';
import 'state/profile_switcher.dart';
import 'state/session_controller.dart';

/// QOL_PLAN E2.4: compact account switcher for the Home app bar. Shows who
/// is signed in (name + server host) and lets you jump to another saved
/// account or add one.
class ProfileMenuButton extends ConsumerWidget {
  const ProfileMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(serverProfilesProvider).valueOrNull ?? const [];
    final activeId = ref.watch(activeProfileIdProvider);
    ServerProfile? active;
    for (final p in profiles) {
      if (p.id == activeId) active = p;
    }
    final others = [
      for (final p in profiles)
        if (p.id != activeId) p,
    ];

    return PopupMenuButton<String>(
      tooltip: context.l10n.accounts,
      icon: const Icon(Icons.account_circle_outlined),
      onSelected: (value) {
        if (value == '_add') {
          context.push('/add-server');
        } else if (value == '_manage') {
          context.push('/account');
        } else {
          final target = profiles.firstWhere((p) => p.id == value);
          confirmAndSwitchProfile(context, ref, target);
        }
      },
      itemBuilder: (ctx) => [
        if (active != null)
          PopupMenuItem<String>(
            enabled: false,
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.check_circle),
              title: Text(active.username),
              subtitle: Text(hostOfServerUrl(active.serverUrl)),
            ),
          ),
        for (final p in others)
          PopupMenuItem<String>(
            value: p.id,
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_outline),
              title: Text(p.username),
              subtitle: Text(hostOfServerUrl(p.serverUrl)),
            ),
          ),
        if (profiles.isNotEmpty) const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: '_add',
          child: Text(ctx.l10n.addServerOrAccount),
        ),
        PopupMenuItem<String>(
          value: '_manage',
          child: Text(ctx.l10n.manageAccounts),
        ),
      ],
    );
  }
}
