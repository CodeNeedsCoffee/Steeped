import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/theme/skin_registry.dart';
import '../auth/state/session_controller.dart';
import '../auth/state/session_state.dart';
import '../ebook/ereader_settings_panel.dart';
import '../player/state/pending_sync_controller.dart';
import '../player/time_display_mode_selector.dart';
import 'data/app_settings.dart';
import 'state/settings_providers.dart';
import '../../l10n/l10n.dart';
import '../../l10n/enum_labels.dart';

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
      appBar: AppBar(title: Text(context.l10n.settings)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(context.l10n.account),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/account'),
          ),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: Text(context.l10n.appearance),
            subtitle: Text(skinByName(settings.skinId).id.localized(context.l10n)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/appearance'),
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart_outlined),
            title: Text(context.l10n.stats),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/stats'),
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: Text(context.l10n.history),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/history'),
          ),
          if (isAdmin)
            ListTile(
              leading: const Icon(Icons.rss_feed),
              title: Text(context.l10n.rssFeeds),
              subtitle: Text(context.l10n.adminNotYetImplemented),
              enabled: false,
            ),

          _SectionHeader(context.l10n.sectionPlayback),
          ListTile(
            title: Text(context.l10n.jumpBack),
            subtitle: Slider(
              value: settings.jumpBackSeconds.toDouble(),
              min: 5,
              max: 120,
              divisions: 23,
              label: '${settings.jumpBackSeconds}s',
              onChanged: (v) => controller.save(
                settings.copyWith(jumpBackSeconds: v.round()),
              ),
            ),
          ),
          ListTile(
            title: Text(context.l10n.jumpForward),
            subtitle: Slider(
              value: settings.jumpForwardSeconds.toDouble(),
              min: 5,
              max: 120,
              divisions: 23,
              label: '${settings.jumpForwardSeconds}s',
              onChanged: (v) => controller.save(
                settings.copyWith(jumpForwardSeconds: v.round()),
              ),
            ),
          ),
          SwitchListTile(
            title: Text(context.l10n.allowSeekingOnLockScreen),
            subtitle: Text(
              context.l10n.showADraggableProgressBar,
            ),
            value: settings.allowSeekOnMediaControls,
            onChanged: (v) =>
                controller.save(settings.copyWith(allowSeekOnMediaControls: v)),
          ),
          ListTile(
            title: Text(context.l10n.autoRewindOnResume),
            subtitle: Text(context.l10n.stepBackALittleWhen),
            trailing: DropdownButton<int>(
              value: const [0, 3, 5, 10, 15, 30].contains(
                    settings.autoRewindSeconds,
                  )
                  ? settings.autoRewindSeconds
                  : 0,
              underline: const SizedBox.shrink(),
              onChanged: (v) {
                if (v != null) {
                  controller.save(settings.copyWith(autoRewindSeconds: v));
                }
              },
              items: [
                for (final v in const [0, 3, 5, 10, 15, 30])
                  DropdownMenuItem(value: v, child: Text(
                      v == 0
                          ? context.l10n.autoRewindOff
                          : context.l10n.secondsShort(v),
                    )),
              ],
            ),
          ),
          if (settings.autoRewindSeconds > 0)
            SwitchListTile(
              title: Text(context.l10n.rewindFurtherAfterLongPauses),
              subtitle: Text(context.l10n.autoRewindScaleHint),
              value: settings.autoRewindScale,
              onChanged: (v) =>
                  controller.save(settings.copyWith(autoRewindScale: v)),
            ),
          SwitchListTile(
            title: Text(context.l10n.scaleElapsedTimeBySpeed),
            subtitle: Text(
              context.l10n.showNowPlayingSTime,
            ),
            value: settings.scaleElapsedTimeBySpeed,
            onChanged: (v) =>
                controller.save(settings.copyWith(scaleElapsedTimeBySpeed: v)),
          ),
          SwitchListTile(
            title: Text(context.l10n.showTracksTab),
            subtitle: Text(
              context.l10n.onNowPlayingAddA,
            ),
            value: settings.showTracksTab,
            onChanged: (v) =>
                controller.save(settings.copyWith(showTracksTab: v)),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 8,
              children: [
                Text(context.l10n.timeDisplayTooltip, style: TextStyle(fontSize: 16)),
                TimeDisplayModeSelector(),
              ],
            ),
          ),

          _SectionHeader(context.l10n.sectionSleepTimer),
          ListTile(
            title: Text(context.l10n.defaultDuration),
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
          ListTile(
            title: Text(context.l10n.extendBy),
            subtitle: Slider(
              value: settings.sleepExtendMinutes.toDouble(),
              min: 1,
              max: 30,
              divisions: 29,
              label: '${settings.sleepExtendMinutes}m',
              onChanged: (v) => controller.save(
                settings.copyWith(sleepExtendMinutes: v.round()),
              ),
            ),
          ),
          SwitchListTile(
            title: Text(context.l10n.fadeOutBeforePausing),
            value: settings.sleepFadeOut,
            onChanged: (v) =>
                controller.save(settings.copyWith(sleepFadeOut: v)),
          ),
          if (settings.sleepFadeOut)
            ListTile(
              title: Text(context.l10n.fadeLength),
              subtitle: Slider(
                value: settings.sleepFadeSeconds.toDouble(),
                min: 3,
                max: 30,
                divisions: 27,
                label: '${settings.sleepFadeSeconds}s',
                onChanged: (v) => controller.save(
                  settings.copyWith(sleepFadeSeconds: v.round()),
                ),
              ),
            ),
          SwitchListTile(
            title: Text(context.l10n.sleepChimeBeforePausing),
            value: settings.sleepChime,
            onChanged: (v) => controller.save(settings.copyWith(sleepChime: v)),
          ),
          SwitchListTile(
            title: Text(context.l10n.startAutomaticallyAtNight),
            subtitle: Text(
              context.l10n.beginTheDefaultTimerWhen,
            ),
            value: settings.sleepAutoWindow,
            onChanged: (v) =>
                controller.save(settings.copyWith(sleepAutoWindow: v)),
          ),
          if (settings.sleepAutoWindow) ...[
            _TimeOfDayTile(
              title: 'Window starts',
              minutes: settings.sleepWindowStartMinutes,
              onChanged: (m) => controller.save(
                settings.copyWith(sleepWindowStartMinutes: m),
              ),
            ),
            _TimeOfDayTile(
              title: 'Window ends',
              minutes: settings.sleepWindowEndMinutes,
              onChanged: (m) =>
                  controller.save(settings.copyWith(sleepWindowEndMinutes: m)),
            ),
          ],

          _SectionHeader(context.l10n.sectionData),
          _CellularPolicyTile(
            title: 'Stream over cellular',
            value: settings.cellularStreaming,
            onChanged: (v) =>
                controller.save(settings.copyWith(cellularStreaming: v)),
          ),
          _CellularPolicyTile(
            title: 'Download over cellular',
            value: settings.cellularDownloads,
            onChanged: (v) =>
                controller.save(settings.copyWith(cellularDownloads: v)),
          ),

          if (Platform.isAndroid)
            SwitchListTile(
              title: Text(context.l10n.treatMeteredWiFiLike),
              subtitle: Text(
                context.l10n.applyTheChoicesAboveTo,
              ),
              value: settings.treatMeteredAsCellular,
              onChanged: (v) =>
                  controller.save(settings.copyWith(treatMeteredAsCellular: v)),
            ),

          _SectionHeader(context.l10n.sectionLibrary),
          SwitchListTile(
            title: Text(context.l10n.rememberLibrarySection),
            subtitle: Text(
              context.l10n.reopenOnBooksAuthorsCollections,
            ),
            value: settings.rememberLibrarySection,
            onChanged: (v) =>
                controller.save(settings.copyWith(rememberLibrarySection: v)),
          ),
          SwitchListTile(
            title: Text(context.l10n.collapseSeries),
            subtitle: Text(
              context.l10n.showEachSeriesAsA,
            ),
            value: settings.collapseSeries,
            onChanged: (v) =>
                controller.save(settings.copyWith(collapseSeries: v)),
          ),

          _SectionHeader(context.l10n.sectionAccount),
          SwitchListTile(
            title: Text(context.l10n.maskServerAddress),
            subtitle: Text(
              context.l10n.hideTheAddressOnThe,
            ),
            value: settings.maskServerAddress,
            onChanged: (v) =>
                controller.save(settings.copyWith(maskServerAddress: v)),
          ),
          SwitchListTile(
            title: Text(context.l10n.askBeforeSwitching),
            subtitle: Text(context.l10n.askBeforeSwitchingHint),
            value: settings.confirmSwitchWhilePlaying,
            onChanged: (v) => controller.save(
              settings.copyWith(confirmSwitchWhilePlaying: v),
            ),
          ),
          SwitchListTile(
            title: Text(context.l10n.showOtherServerDownloads),
            subtitle: Text(context.l10n.showOtherServerDownloadsHint),
            value: settings.showOtherServerDownloads,
            onChanged: (v) => controller.save(
              settings.copyWith(showOtherServerDownloads: v),
            ),
          ),

          _SectionHeader(context.l10n.sectionUserInterface),
          if (Platform.isAndroid)
            SwitchListTile(
              title: Text(context.l10n.showNetworkTypeOnThe),
              subtitle: Text(context.l10n.forExampleLiveMetered),
              value: settings.showNetworkType,
              onChanged: (v) =>
                  controller.save(settings.copyWith(showNetworkType: v)),
            ),
          SwitchListTile(
            title: Text(context.l10n.hapticFeedback),
            value: settings.hapticFeedbackEnabled,
            onChanged: (v) =>
                controller.save(settings.copyWith(hapticFeedbackEnabled: v)),
          ),
          SwitchListTile(
            title: Text(context.l10n.keepScreenAwakeWhilePlaying),
            value: settings.keepScreenAwake,
            onChanged: (v) =>
                controller.save(settings.copyWith(keepScreenAwake: v)),
          ),
          SwitchListTile(
            title: Text(context.l10n.lockToPortrait),
            value: settings.lockPortrait,
            onChanged: (v) =>
                controller.save(settings.copyWith(lockPortrait: v)),
          ),
          ListTile(
            title: Text(context.l10n.language),
            subtitle: Text(
              context.l10n.englishTheOnlyLanguageTranslated,
            ),
            trailing: Text(context.l10n.english),
          ),

          _SectionHeader(context.l10n.sectionEreader),
          const EreaderSettingsPanel(),

          if (Platform.isAndroid) ...[
            _SectionHeader(context.l10n.sectionAndroidAuto),
            ListTile(
              title: Text(context.l10n.itemsPerList),
              subtitle: Text(context.l10n.howManyEntriesEachBrowse),
              trailing: DropdownButton<int>(
                value: const [20, 40, 100].contains(settings.autoBrowseLimit)
                    ? settings.autoBrowseLimit
                    : 40,
                underline: const SizedBox.shrink(),
                onChanged: (v) {
                  if (v != null) {
                    controller.save(settings.copyWith(autoBrowseLimit: v));
                  }
                },
                items: const [
                  DropdownMenuItem(value: 20, child: Text('20')),
                  DropdownMenuItem(value: 40, child: Text('40')),
                  DropdownMenuItem(value: 100, child: Text('100')),
                ],
              ),
            ),
            SwitchListTile(
              title: Text(context.l10n.newestBookFirstInA),
              subtitle: Text(context.l10n.otherwiseBooksListInReading),
              value: settings.autoSeriesNewestFirst,
              onChanged: (v) =>
                  controller.save(settings.copyWith(autoSeriesNewestFirst: v)),
            ),
          ],

          _SectionHeader(context.l10n.sectionAdvanced),
          const _PendingSyncTile(),
          SwitchListTile(
            title: Text(context.l10n.showSyncFailedIndicator),
            subtitle: Text(
              context.l10n.badgeOnThePlayerWhile,
            ),
            value: settings.showSyncIndicator,
            onChanged: (v) =>
                controller.save(settings.copyWith(showSyncIndicator: v)),
          ),
          if (Platform.isAndroid) const _BatteryOptimizationTile(),
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: Text(context.l10n.localMedia),
            subtitle: Text(
              context.l10n.importOnDeviceAudioFiles,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/local-media'),
          ),
          ListTile(
            leading: const Icon(Icons.article_outlined),
            title: Text(context.l10n.logs),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/logs'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

/// Bug fix 2026-09-22 (evan: streamed playback silently stalling while the
/// phone is locked). Android's app-standby/Doze battery management can
/// throttle a backgrounded app's audio focus and networking even with a
/// correctly-declared `mediaPlayback` foreground service (see
/// AndroidManifest.xml) — confirmed live via `adb shell cmd appops get`
/// showing `TAKE_AUDIO_FOCUS`/`CONTROL_AUDIO` scoped to foreground-only for
/// this app. `Permission.ignoreBatteryOptimizations` is the user-facing,
/// Play-Store-safe way to ask the OS to exempt Steeped from that (the
/// `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` manifest permission only lets the
/// app *ask*; Android still shows its own system dialog for the user to
/// accept). iOS has no equivalent concept — `UIBackgroundModes: audio`
/// (Info.plist) is the entire story there — so this tile is Android-only.
class _BatteryOptimizationTile extends StatefulWidget {
  const _BatteryOptimizationTile();

  @override
  State<_BatteryOptimizationTile> createState() =>
      _BatteryOptimizationTileState();
}

class _BatteryOptimizationTileState extends State<_BatteryOptimizationTile>
    with WidgetsBindingObserver {
  PermissionStatus? _status;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A `.request()` that falls through to the system Settings app (some
    // OEMs do this instead of the in-app dialog) only updates `_status`
    // once the user comes back here, not when `request()` itself returns.
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final status = await Permission.ignoreBatteryOptimizations.status;
    if (mounted) setState(() => _status = status);
  }

  Future<void> _request() async {
    final status = await Permission.ignoreBatteryOptimizations.request();
    if (mounted) setState(() => _status = status);
  }

  @override
  Widget build(BuildContext context) {
    final granted = _status?.isGranted ?? false;
    return ListTile(
      leading: const Icon(Icons.battery_charging_full_outlined),
      title: Text(context.l10n.unrestrictedBackgroundPlayback),
      subtitle: Text(
        granted
            ? context.l10n.batteryExempt
            : context.l10n.batteryRecommended,
      ),
      trailing: granted
          ? Icon(
              Icons.check_circle,
              color: Theme.of(context).colorScheme.primary,
            )
          : const Icon(Icons.chevron_right),
      onTap: granted ? null : _request,
    );
  }
}

class _PendingSyncTile extends ConsumerWidget {
  const _PendingSyncTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(pendingSyncCountProvider).valueOrNull ?? 0;
    return ListTile(
      leading: const Icon(Icons.sync_outlined),
      title: Text(context.l10n.progressSync),
      subtitle: Text(
        count == 0
            ? context.l10n.progressSyncAllSynced
            : context.l10n.updatesWaitingToSync(count),
      ),
      trailing: count == 0
          ? null
          : TextButton(
              onPressed: () =>
                  ref.read(pendingSyncControllerProvider.notifier).flushPending(),
              child: Text(context.l10n.retryNow),
            ),
    );
  }
}

class _TimeOfDayTile extends StatelessWidget {
  const _TimeOfDayTile({
    required this.title,
    required this.minutes,
    required this.onChanged,
  });

  final String title;
  final int minutes;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final time = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
    return ListTile(
      title: Text(title),
      trailing: Text(time.format(context)),
      onTap: () async {
        final picked = await showTimePicker(context: context, initialTime: time);
        if (picked != null) onChanged(picked.hour * 60 + picked.minute);
      },
    );
  }
}

class _CellularPolicyTile extends StatelessWidget {
  const _CellularPolicyTile({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final CellularPolicy value;
  final ValueChanged<CellularPolicy> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      trailing: DropdownButton<CellularPolicy>(
        value: value,
        underline: const SizedBox.shrink(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
        items: [
          DropdownMenuItem(value: CellularPolicy.always, child: Text(context.l10n.always)),
          DropdownMenuItem(value: CellularPolicy.ask, child: Text(context.l10n.ask)),
          DropdownMenuItem(value: CellularPolicy.never, child: Text(context.l10n.never)),
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
