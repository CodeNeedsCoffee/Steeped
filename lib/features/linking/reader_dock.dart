import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format_duration.dart';
import '../../l10n/l10n.dart';
import '../../models/library_item_detail.dart';
import '../../core/network/cover_image_url.dart';
import '../../widgets/cover_image.dart';
import '../auth/state/session_controller.dart';
import '../auth/state/session_state.dart';
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
    super.key,
  });

  final LibraryItemDetail audio;
  final bool following;
  final VoidCallback onToggleFollow;

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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final radii = theme.extension<AppRadii>() ?? const AppRadii();
    // Same accent-tinted card as the mini player, so it reads as the app's
    // player sitting on the page and not as more page.
    final fill = Color.alphaBlend(
      scheme.primary.withValues(alpha: 0.22),
      scheme.surfaceContainerHigh,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: fill,
        elevation: 6,
        shadowColor: scheme.primary.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(radii.lg),
        clipBehavior: Clip.antiAlias,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radii.lg),
            border: Border.all(color: scheme.primary.withValues(alpha: 0.35)),
          ),
          child: IconTheme(
            data: IconThemeData(color: scheme.onSurface),
            child: SizedBox(
              height: 56,
              child: Row(
                children: [
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.replay),
                    iconSize: 28,
                    visualDensity: VisualDensity.compact,
                    tooltip: l10n.rewindSeconds(back),
                    onPressed: controller.jumpBackward,
                  ),
                  IconButton(
                    icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                    iconSize: 36,
                    visualDensity: VisualDensity.compact,
                    tooltip: playing ? l10n.pause : l10n.play,
                    onPressed: () =>
                        playing ? controller.pause() : controller.resume(),
                  ),
                  IconButton(
                    icon: Transform.flip(
                      flipX: true,
                      child: const Icon(Icons.replay),
                    ),
                    iconSize: 28,
                    visualDensity: VisualDensity.compact,
                    tooltip: l10n.forwardSeconds(fwd),
                    onPressed: controller.jumpForward,
                  ),
                  const SizedBox(width: 8),
                  // The bar sits on the row's centre line, in line with the
                  // buttons; the time left hangs below it without moving it.
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          LinearProgressIndicator(
                            value: ratio,
                            minHeight: 4,
                            borderRadius: BorderRadius.circular(2),
                            color: scheme.primary,
                            backgroundColor: scheme.onSurface.withValues(
                              alpha: 0.15,
                            ),
                          ),
                          if (progress != null)
                            Positioned(
                              left: 0,
                              top: 28 + 6,
                              child: Text(
                                l10n.timeLeftShort(
                                  formatDurationText(l10n, progress.left),
                                ),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.onSurface.withValues(
                                    alpha: 0.75,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      following ? Icons.my_location : Icons.location_searching,
                    ),
                    visualDensity: VisualDensity.compact,
                    tooltip: following ? l10n.followingAudio : l10n.followAudio,
                    isSelected: following,
                    color: following ? scheme.primary : null,
                    onPressed: onToggleFollow,
                  ),
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_up),
                    visualDensity: VisualDensity.compact,
                    tooltip: l10n.expandPlayer,
                    onPressed: () => _expand(context, ref),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _expand(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => PlayerExtras(audio: audio),
    );
  }
}

/// Chapter skips, speed and sleep timer for the linked audiobook: the body of
/// the strip's expand sheet and the lower part of the side panel.
class PlayerExtras extends ConsumerWidget {
  const PlayerExtras({required this.audio});

  final LibraryItemDetail audio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final controller = ref.read(playbackControllerProvider.notifier);
    final seconds = ref.watch(playbackPositionProvider).valueOrNull ?? 0;
    final speed = ref.watch(playbackSpeedProvider).valueOrNull ?? 1.0;
    final progress = chapterProgressAt(audioSpansOf(audio), seconds);
    final remaining = ref.watch(sleepTimerRemainingProvider);
    final endOfChapter = ref.watch(sleepTimerEndOfChapterProvider);
    final setMinutes = remaining == null || endOfChapter
        ? null
        : controller.lastSleepDuration.inMinutes;
    final left = remaining?.inSeconds ?? 0;
    final clock = '${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}';
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
                style: theme.textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 8),
            Text(
              '${speed.toStringAsFixed(2)}x',
              style: theme.textTheme.titleLarge,
            ),
            Slider(
              value: speed.clamp(0.5, 3.0),
              min: 0.5,
              max: 3.0,
              divisions: 25,
              onChanged: controller.setSpeed,
            ),
            const SizedBox(height: 8),
            if (remaining != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.bedtime_outlined,
                      size: 20,
                      color: scheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        endOfChapter
                            ? l10n.chapterEndsIn(clock)
                            : l10n.sleepIn(clock),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: controller.cancelSleepTimer,
                      child: Text(l10n.cancel),
                    ),
                  ],
                ),
              ),
            Wrap(
              spacing: 8,
              children: [
                for (final m in const [15, 30, 45, 60])
                  ChoiceChip(
                    label: Text(l10n.minutes(m)),
                    selected: setMinutes == m,
                    showCheckmark: true,
                    onSelected: (_) =>
                        controller.startSleepTimer(Duration(minutes: m)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The player as a fixed column beside the page (landscape and tablets, where
/// there is room): cover, title, chapter, progress, controls and the extras.
class ReaderPlayerPanel extends ConsumerWidget {
  const ReaderPlayerPanel({
    required this.audio,
    required this.following,
    required this.onToggleFollow,
    super.key,
  });

  final LibraryItemDetail audio;
  final bool following;
  final VoidCallback onToggleFollow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
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
    final session = ref.watch(sessionControllerProvider);
    final (serverUrl, token) = switch (session) {
      SessionAuthenticated(:final serverUrl, :final user) => (
        serverUrl,
        user.effectiveToken,
      ),
      _ => (null, null),
    };
    return Material(
      color: theme.colorScheme.surfaceContainer,
      child: SafeArea(
        left: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (serverUrl != null)
                Center(
                  child: CoverImage(
                    url: coverImageUrl(
                      serverUrl: serverUrl,
                      itemId: audio.id,
                      token: token,
                      updatedAt: audio.updatedAt,
                    ),
                    width: 140,
                    height: 140,
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                audio.title,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (progress != null && progress.title.isNotEmpty)
                Text(
                  progress.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: ratio, minHeight: 4),
              if (progress != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    l10n.timeLeftShort(formatDurationText(l10n, progress.left)),
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.replay),
                    tooltip: l10n.rewindSeconds(
                      ref
                              .watch(appSettingsProvider)
                              .valueOrNull
                              ?.jumpBackSeconds ??
                          30,
                    ),
                    onPressed: controller.jumpBackward,
                  ),
                  IconButton.filled(
                    iconSize: 36,
                    icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                    tooltip: playing ? l10n.pause : l10n.play,
                    onPressed: () =>
                        playing ? controller.pause() : controller.resume(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.fast_forward),
                    tooltip: l10n.forwardSeconds(
                      ref
                              .watch(appSettingsProvider)
                              .valueOrNull
                              ?.jumpForwardSeconds ??
                          30,
                    ),
                    onPressed: controller.jumpForward,
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.followingAudio),
                value: following,
                onChanged: (_) => onToggleFollow(),
              ),
              PlayerExtras(audio: audio),
            ],
          ),
        ),
      ),
    );
  }
}

/// Room for the side panel: a phone in landscape or a tablet.
bool wideEnoughForPanel(double width) => width >= 720;
