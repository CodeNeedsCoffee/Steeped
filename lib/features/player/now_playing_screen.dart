import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/network/cover_image_url.dart';
import '../../widgets/cover_image.dart';
import '../auth/state/session_controller.dart';
import '../auth/state/session_state.dart';
import '../settings/data/app_settings.dart';
import '../settings/state/settings_providers.dart';
import 'state/playback_controller.dart';

/// PLAN.md Phase 5.2 (full-screen Now Playing), 5.5 (chapters + jump
/// forward/back — interval now configurable, Phase 9.3), 5.6 (speed), 5.7
/// (sleep timer — basic manual-duration version), 5.10 (mark
/// finished/not finished), 9.3 (keep-screen-awake, scale-elapsed-by-speed).
class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen> {
  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings =
        ref.watch(appSettingsProvider).valueOrNull ?? const AppSettings();
    if (settings.keepScreenAwake) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }

    final item = ref.watch(currentPlaybackItemProvider);
    if (item == null) {
      // Briefly true right after tapping Play, while playItem() is still
      // fetching item detail — genuinely nothing loaded yet if it persists.
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final session = ref.watch(sessionControllerProvider);
    final position = ref.watch(playbackPositionProvider).valueOrNull ?? 0.0;
    final isPlaying = ref.watch(isPlayingProvider).valueOrNull ?? false;
    final sleepRemaining = ref.watch(sleepTimerRemainingProvider);
    final controller = ref.read(playbackControllerProvider.notifier);
    final (serverUrl, token) = switch (session) {
      SessionAuthenticated(:final serverUrl, :final user) => (
        serverUrl,
        user.effectiveToken,
      ),
      _ => (null, null),
    };
    final duration = item.duration ?? (position == 0 ? 1.0 : position);
    final currentChapterIndex = item.chapters.indexWhere(
      (c) => position >= c.start && position < c.end,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: Icon(
              sleepRemaining != null
                  ? Icons.bedtime
                  : Icons.bedtime_outlined,
            ),
            tooltip: sleepRemaining != null
                ? 'Sleep timer: ${_formatTime(sleepRemaining.inSeconds.toDouble())}'
                : 'Sleep timer',
            onPressed: () => _showSleepTimerSheet(context, ref, settings),
          ),
          PopupMenuButton<bool>(
            onSelected: controller.markFinished,
            itemBuilder: (context) => const [
              PopupMenuItem(value: true, child: Text('Mark as Finished')),
              PopupMenuItem(value: false, child: Text('Mark as Not Finished')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (serverUrl != null)
            Center(
              child: CoverImage(
                url: coverImageUrl(
                  serverUrl: serverUrl,
                  itemId: item.id,
                  token: token,
                  updatedAt: item.updatedAt,
                ),
                width: 240,
                height: 240,
              ),
            ),
          const SizedBox(height: 16),
          Text(
            item.title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          if (item.authors.isNotEmpty)
            Text(
              item.authorNames,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          const SizedBox(height: 20),
          Slider(
            value: position.clamp(0, duration),
            max: duration,
            onChanged: controller.seekToGlobalPosition,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Builder(
              builder: (context) {
                final speed = settings.scaleElapsedTimeBySpeed
                    ? (ref.watch(playbackSpeedProvider).valueOrNull ?? 1.0)
                    : 1.0;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatTime(position / speed)),
                    Text(_formatTime(duration / speed)),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                iconSize: 36,
                icon: const Icon(Icons.replay_30),
                onPressed: controller.jumpBackward,
              ),
              const SizedBox(width: 16),
              IconButton(
                iconSize: 56,
                icon: Icon(
                  isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                ),
                onPressed: () {
                  if (settings.hapticFeedbackEnabled) {
                    HapticFeedback.lightImpact();
                  }
                  isPlaying ? controller.pause() : controller.resume();
                },
              ),
              const SizedBox(width: 16),
              IconButton(
                iconSize: 36,
                icon: const Icon(Icons.forward_30),
                onPressed: controller.jumpForward,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Center(child: _SpeedSelector(onChanged: controller.setSpeed)),
          if (item.chapters.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Chapters', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...item.chapters.asMap().entries.map((entry) {
              return ListTile(
                dense: true,
                selected: entry.key == currentChapterIndex,
                title: Text(entry.value.title),
                trailing: Text(_formatTime(entry.value.start)),
                onTap: () => controller.seekToGlobalPosition(entry.value.start),
              );
            }),
          ],
        ],
      ),
    );
  }

  String _formatTime(double seconds) {
    final total = seconds.round();
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    final mm = m.toString().padLeft(h > 0 ? 2 : 1, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  void _showSleepTimerSheet(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    final controller = ref.read(playbackControllerProvider.notifier);
    final isActive = ref.read(sleepTimerRemainingProvider) != null;
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Sleep Timer'),
            ),
            for (final minutes in {
              5,
              15,
              30,
              45,
              60,
              settings.sleepTimerDefaultMinutes,
            }.toList()..sort())
              ListTile(
                title: Text('$minutes minutes'),
                onTap: () {
                  controller.startSleepTimer(Duration(minutes: minutes));
                  Navigator.pop(context);
                },
              ),
            if (isActive)
              ListTile(
                leading: const Icon(Icons.cancel_outlined),
                title: const Text('Cancel timer'),
                onTap: () {
                  controller.cancelSleepTimer();
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _SpeedSelector extends StatefulWidget {
  const _SpeedSelector({required this.onChanged});

  final ValueChanged<double> onChanged;

  @override
  State<_SpeedSelector> createState() => _SpeedSelectorState();
}

class _SpeedSelectorState extends State<_SpeedSelector> {
  double _speed = 1.0;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<double>(
      value: _speed,
      items: const [0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
          .map((s) => DropdownMenuItem(value: s, child: Text('${s}x')))
          .toList(),
      onChanged: (value) {
        if (value == null) return;
        setState(() => _speed = value);
        widget.onChanged(value);
      },
    );
  }
}
