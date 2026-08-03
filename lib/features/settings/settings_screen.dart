import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/skin_registry.dart';
import '../auth/state/session_controller.dart';
import '../auth/state/session_state.dart';
import '../ebook/ereader_settings_panel.dart';
import '../player/time_display_mode_selector.dart';
import 'data/app_settings.dart';
import 'state/settings_providers.dart';

/// PLAN.md Phase 9.3: settings taxonomy matching the reference app —
/// Playback, Data, User Interface, Ereader, Sleep Timer, Advanced. Every
/// toggle here is wired to real behavior (see PLAN.md Phase 9 for exactly
/// where each one is consumed) — no dead switches.
///
/// **Appearance** (PLAN.md Phase 2.6) fills the slot this screen's Phase
/// 9.3 note originally left reserved — a real skin switcher now exists,
/// see `AppearanceScreen`.
///
/// Not included: **Android Auto** (Milestone 4, nothing to configure yet).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    final settingsAsync = ref.watch(appSettingsProvider);
    final settings = settingsAsync.valueOrNull ?? const AppSettings();
    final controller = ref.read(appSettingsProvider.notifier);
    final isAdmin =
        session is SessionAuthenticated &&
        (session.user.type == 'root' || session.user.type == 'admin');

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Account'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/account'),
          ),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Appearance'),
            subtitle: Text(skinByName(settings.skinId).displayName),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/appearance'),
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart_outlined),
            title: const Text('Stats'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/stats'),
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('History'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/history'),
          ),
          if (isAdmin)
            ListTile(
              leading: const Icon(Icons.rss_feed),
              title: const Text('RSS Feeds'),
              subtitle: const Text('Admin — not yet implemented'),
              enabled: false,
            ),

          const _SectionHeader('Playback'),
          ListTile(
            title: const Text('Jump interval'),
            subtitle: Slider(
              value: settings.jumpIntervalSeconds.toDouble(),
              min: 10,
              max: 60,
              divisions: 10,
              label: '${settings.jumpIntervalSeconds}s',
              onChanged: (v) => controller.save(
                settings.copyWith(jumpIntervalSeconds: v.round()),
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('Scale elapsed time by speed'),
            subtitle: const Text(
              'Show Now Playing\'s time as real-world minutes at your current speed',
            ),
            value: settings.scaleElapsedTimeBySpeed,
            onChanged: (v) => controller.save(
              settings.copyWith(scaleElapsedTimeBySpeed: v),
            ),
          ),
          SwitchListTile(
            title: const Text('Show Tracks tab'),
            subtitle: const Text(
              'On Now Playing, add a toggle to switch between chapters and '
              'a multi-file book\'s raw audio-file tracks',
            ),
            value: settings.showTracksTab,
            onChanged: (v) =>
                controller.save(settings.copyWith(showTracksTab: v)),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Time display',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                TimeDisplayModeSelector(),
              ],
            ),
          ),

          const _SectionHeader('Sleep Timer'),
          ListTile(
            title: const Text('Default duration'),
            subtitle: Slider(
              value: settings.sleepTimerDefaultMinutes.toDouble(),
              min: 5,
              max: 90,
              divisions: 17,
              label: '${settings.sleepTimerDefaultMinutes}m',
              onChanged: (v) => controller.save(
                settings.copyWith(sleepTimerDefaultMinutes: v.round()),
              ),
            ),
          ),

          const _SectionHeader('Data'),
          SwitchListTile(
            title: const Text('Stream over cellular'),
            value: settings.allowCellularStreaming,
            onChanged: (v) =>
                controller.save(settings.copyWith(allowCellularStreaming: v)),
          ),
          SwitchListTile(
            title: const Text('Download over cellular'),
            value: settings.allowCellularDownloads,
            onChanged: (v) =>
                controller.save(settings.copyWith(allowCellularDownloads: v)),
          ),

          const _SectionHeader('User Interface'),
          SwitchListTile(
            title: const Text('Haptic feedback'),
            value: settings.hapticFeedbackEnabled,
            onChanged: (v) =>
                controller.save(settings.copyWith(hapticFeedbackEnabled: v)),
          ),
          SwitchListTile(
            title: const Text('Keep screen awake while playing'),
            value: settings.keepScreenAwake,
            onChanged: (v) =>
                controller.save(settings.copyWith(keepScreenAwake: v)),
          ),
          SwitchListTile(
            title: const Text('Lock to portrait'),
            value: settings.lockPortrait,
            onChanged: (v) =>
                controller.save(settings.copyWith(lockPortrait: v)),
          ),
          const ListTile(
            title: Text('Language'),
            subtitle: Text(
              'English — the only language translated so far (Phase 9.8); '
              'the picker will grow as more ARB translations are added',
            ),
            trailing: Text('English'),
          ),

          const _SectionHeader('Ereader'),
          const EreaderSettingsPanel(),

          const _SectionHeader('Advanced'),
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: const Text('Local Media'),
            subtitle: const Text(
              'Import on-device audio files that never came from the server',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/local-media'),
          ),
          ListTile(
            leading: const Icon(Icons.article_outlined),
            title: const Text('Logs'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/logs'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}
