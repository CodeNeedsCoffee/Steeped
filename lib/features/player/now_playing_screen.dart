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
import 'time_display_mode_selector.dart';

/// PLAN.md Phase 5.2 (full-screen Now Playing), 5.5 (chapters + jump
/// forward/back — interval now configurable, Phase 9.3), 5.6 (speed), 5.7
/// (sleep timer — basic manual-duration version), 5.10 (mark
/// finished/not finished), 9.3 (keep-screen-awake, scale-elapsed-by-speed).
class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

enum _TrackListMode { chapters, tracks }

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen> {
  _TrackListMode _listMode = _TrackListMode.chapters;

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
    final currentChapter = currentChapterIndex >= 0
        ? item.chapters[currentChapterIndex]
        : null;
    // Chapter time only actually shows when there's a current chapter to be
    // relative to — a book with no chapter metadata (or a position that
    // hasn't matched one yet) always falls back to showing book time, so
    // the row is never just blank even if "Chapter" is the only mode on.
    final showChapterTime = settings.showChapterTime && currentChapter != null;
    final showBookTime = settings.showBookTime || !showChapterTime;
    final chapterElapsed = currentChapter == null
        ? 0.0
        : (position - currentChapter.start).clamp(
            0.0,
            currentChapter.end - currentChapter.start,
          );
    final chapterDuration = currentChapter == null
        ? 0.0
        : currentChapter.end - currentChapter.start;
    final currentTrackIndex = item.tracks.indexWhere(
      (t) => position >= t.startOffset && position < t.endOffset,
    );
    // A single-track book has nothing a "Tracks" view would add over
    // "Chapters" (or vice versa if it has no chapter metadata) — only offer
    // the toggle when both views would actually show something different.
    // Also gated on the Settings → Playback "Show Tracks tab" toggle
    // (off by default) so most books/listeners never see this at all.
    final hasChapters = item.chapters.isNotEmpty;
    final hasTracks = settings.showTracksTab && item.tracks.length > 1;
    final showChapters =
        hasChapters && (!hasTracks || _listMode == _TrackListMode.chapters);

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
          IconButton(
            icon: const Icon(Icons.timer_outlined),
            tooltip: 'Time display',
            onPressed: () => _showTimeDisplaySheet(context),
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
                return Column(
                  children: [
                    if (showChapterTime)
                      _TimeRow(
                        label: showBookTime ? 'Chapter' : null,
                        elapsed: _formatTime(chapterElapsed / speed),
                        total: _formatTime(chapterDuration / speed),
                      ),
                    if (showChapterTime && showBookTime)
                      const SizedBox(height: 6),
                    if (showBookTime)
                      _TimeRow(
                        label: showChapterTime ? 'Book' : null,
                        elapsed: _formatTime(position / speed),
                        total: _formatTime(duration / speed),
                      ),
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
          if (hasChapters || hasTracks) ...[
            const SizedBox(height: 24),
            if (hasChapters && hasTracks)
              Center(
                child: SegmentedButton<_TrackListMode>(
                  segments: const [
                    ButtonSegment(
                      value: _TrackListMode.chapters,
                      label: Text('Chapters'),
                    ),
                    ButtonSegment(
                      value: _TrackListMode.tracks,
                      label: Text('Tracks'),
                    ),
                  ],
                  selected: {_listMode},
                  onSelectionChanged: (s) =>
                      setState(() => _listMode = s.first),
                ),
              )
            else
              Text(
                showChapters ? 'Chapters' : 'Tracks',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            const SizedBox(height: 8),
            if (showChapters)
              ...item.chapters.asMap().entries.map((entry) {
                return ListTile(
                  dense: true,
                  selected: entry.key == currentChapterIndex,
                  title: Text(entry.value.title),
                  trailing: Text(_formatTime(entry.value.start)),
                  onTap: () =>
                      controller.seekToGlobalPosition(entry.value.start),
                );
              })
            else
              ...item.tracks.asMap().entries.map((entry) {
                final track = entry.value;
                return ListTile(
                  dense: true,
                  selected: entry.key == currentTrackIndex,
                  title: Text(track.title ?? 'Track ${entry.key + 1}'),
                  trailing: Text(_formatTime(track.startOffset)),
                  onTap: () =>
                      controller.seekToGlobalPosition(track.startOffset),
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

  void _showTimeDisplaySheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Time Display'),
              SizedBox(height: 12),
              TimeDisplayModeSelector(),
            ],
          ),
        ),
      ),
    );
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

/// One elapsed/total pair, with an optional small caption above it (only
/// used when both chapter and book time are showing at once — a single row
/// stays unlabeled, matching how this looked before the toggle existed).
class _TimeRow extends StatelessWidget {
  const _TimeRow({required this.elapsed, required this.total, this.label});

  final String elapsed;
  final String total;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(elapsed), Text(total)],
    );
    final label = this.label;
    if (label == null) return row;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        row,
      ],
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
