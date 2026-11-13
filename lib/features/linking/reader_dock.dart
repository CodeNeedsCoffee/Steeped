import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/format_duration.dart';
import '../../l10n/l10n.dart';
import '../../models/library_item_detail.dart';
import '../player/state/playback_controller.dart';
import '../settings/state/settings_providers.dart';
import 'link_switch.dart';
import 'read_along.dart';

/// The player strip docked inside the reader while the linked audiobook is
/// loaded: play/pause, skips, the chapter's time left, a Follow toggle and an
/// expand handle that opens speed, sleep timer and chapter skips.
class ReaderPlayerDock extends ConsumerWidget {
  const ReaderPlayerDock({
    required this.audio,
    required this.following,
    required this.onToggleFollow,
    required this.color,
    super.key,
  });

  final LibraryItemDetail audio;
  final bool following;
  final VoidCallback onToggleFollow;

  /// Text and icon colour, from the reader theme.
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playing = ref.watch(isPlayingProvider).valueOrNull ?? false;
    final seconds = ref.watch(playbackPositionProvider).valueOrNull ?? 0;
    final controller = ref.read(playbackControllerProvider.notifier);
    final progress = chapterProgressAt(audioSpansOf(audio), seconds);
    final ratio = progress == null || progress.end <= progress.start
        ? 0.0
        : ((seconds - progress.start) / (progress.end - progress.start)).clamp(
            0.0,
            1.0,
          );
    final l10n = context.l10n;
    final settings = ref.watch(appSettingsProvider).valueOrNull;
    final back = settings?.jumpBackSeconds ?? 30;
    final fwd = settings?.jumpForwardSeconds ?? 30;
    return IconTheme(
      data: IconThemeData(color: color),
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            IconButton(
              icon: Icon(playing ? Icons.pause : Icons.play_arrow),
              tooltip: playing ? l10n.pause : l10n.play,
              onPressed: () =>
                  playing ? controller.pause() : controller.resume(),
            ),
            IconButton(
              icon: const Icon(Icons.replay),
              tooltip: l10n.rewindSeconds(back),
              onPressed: controller.jumpBackward,
            ),
            IconButton(
              icon: const Icon(Icons.fast_forward),
              tooltip: l10n.forwardSeconds(fwd),
              onPressed: controller.jumpForward,
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(value: ratio, minHeight: 3),
                  if (progress != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        l10n.timeLeftShort(
                          formatDurationText(l10n, progress.left),
                        ),
                        style: TextStyle(color: color, fontSize: 11),
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                following ? Icons.my_location : Icons.location_searching,
              ),
              tooltip: following ? l10n.followingAudio : l10n.followAudio,
              isSelected: following,
              onPressed: onToggleFollow,
            ),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_up),
              tooltip: l10n.expandPlayer,
              onPressed: () => _expand(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  void _expand(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => _DockSheet(audio: audio),
    );
  }
}

/// Speed, sleep timer and chapter skips for the linked audiobook.
class _DockSheet extends ConsumerWidget {
  const _DockSheet({required this.audio});

  final LibraryItemDetail audio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final controller = ref.read(playbackControllerProvider.notifier);
    final seconds = ref.watch(playbackPositionProvider).valueOrNull ?? 0;
    final speed = ref.watch(playbackSpeedProvider).valueOrNull ?? 1.0;
    final spans = audioSpansOf(audio);
    final progress = chapterProgressAt(spans, seconds);
    final sleeping = ref.watch(sleepTimerRemainingProvider) != null;
    final idx = progress == null
        ? -1
        : spans.indexWhere((c) => c.start == progress.start);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (progress != null && progress.title.isNotEmpty)
              Text(
                progress.title,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.skip_previous),
                  onPressed: idx < 0
                      ? null
                      : () => controller.seekToGlobalPosition(
                          seconds - spans[idx].start < 5 && idx > 0
                              ? spans[idx - 1].start
                              : spans[idx].start,
                        ),
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next),
                  onPressed: idx < 0 || idx >= spans.length - 1
                      ? null
                      : () => controller.seekToGlobalPosition(
                          spans[idx + 1].start,
                        ),
                ),
                const Spacer(),
                Text('${speed.toStringAsFixed(2)}x'),
              ],
            ),
            Slider(
              value: speed.clamp(0.5, 3.0),
              min: 0.5,
              max: 3.0,
              divisions: 25,
              onChanged: controller.setSpeed,
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final m in const [15, 30, 45, 60])
                  ChoiceChip(
                    label: Text(l10n.minutes(m)),
                    selected: false,
                    onSelected: (_) =>
                        controller.startSleepTimer(Duration(minutes: m)),
                  ),
                if (sleeping)
                  ActionChip(
                    label: Text(l10n.cancel),
                    onPressed: controller.cancelSleepTimer,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
