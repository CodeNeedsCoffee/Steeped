import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/network/cover_image_url.dart';
import '../../models/bookmark.dart';
import '../../models/library_item_detail.dart';
import '../../widgets/cover_image.dart';
import '../../widgets/playback_loading_badge.dart';
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

/// Overflow-menu mirror of the sleep-timer/time-display app-bar icons —
/// both routes end up calling the exact same sheet-opening methods, so
/// either one works identically.
enum _OverflowAction { sleepTimer, timeDisplay, markFinished, markNotFinished }

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
    // PLAN.md Phase 5.14 reuse: the same fetch-then-buffer spinner other
    // Play-triggering rows show, plus the automatic reconnect-after-error
    // retry (see PlaybackController._recoverFromPlayerError) — so a stream
    // drop/reconnect is visibly different from "just playing" instead of
    // the button silently sitting on whatever icon it last had.
    final isConnecting =
        ref.watch(playbackLoadingIdProvider) == item.downloadId ||
        ref.watch(isReconnectingProvider);
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
    // PLAN.md Phase 5.8: bookmarks live server-side keyed only by
    // libraryItemId (confirmed against real server source, including its
    // own TODO admitting this doesn't support podcasts) — offering the
    // action for an episode would silently attach the bookmark to the whole
    // podcast instead of the episode, and local-only media has no server
    // item to attach one to at all.
    final canBookmark = !item.isLocalOnly && !item.isEpisode;
    final bookmarks = canBookmark
        ? ref.watch(bookmarksProvider(item.id)).valueOrNull ?? const []
        : const <Bookmark>[];

    return Scaffold(
      appBar: AppBar(
        // A down-chevron rather than a back arrow: this screen slides up
        // from the mini-player (see the '/now-playing' route's
        // CustomTransitionPage in app_router.dart), so closing it should
        // read as "collapse back down," not "go back."
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down),
          iconSize: 32,
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
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
          PopupMenuButton<_OverflowAction>(
            onSelected: (action) {
              switch (action) {
                case _OverflowAction.sleepTimer:
                  _showSleepTimerSheet(context, ref, settings);
                case _OverflowAction.timeDisplay:
                  _showTimeDisplaySheet(context);
                case _OverflowAction.markFinished:
                  controller.markFinished(true);
                case _OverflowAction.markNotFinished:
                  controller.markFinished(false);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _OverflowAction.sleepTimer,
                child: Text('Sleep Timer'),
              ),
              PopupMenuItem(
                value: _OverflowAction.timeDisplay,
                child: Text('Time Display'),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: _OverflowAction.markFinished,
                child: Text('Mark as Finished'),
              ),
              PopupMenuItem(
                value: _OverflowAction.markNotFinished,
                child: Text('Mark as Not Finished'),
              ),
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
          Builder(
            builder: (context) {
              final speed = settings.scaleElapsedTimeBySpeed
                  ? (ref.watch(playbackSpeedProvider).valueOrNull ?? 1.0)
                  : 1.0;
              final chapterMax = chapterDuration <= 0 ? 1.0 : chapterDuration;
              return Column(
                children: [
                  if (showChapterTime)
                    _ProgressSection(
                      label: showBookTime ? 'Chapter' : null,
                      value: chapterElapsed,
                      max: chapterMax,
                      onChanged: (value) => controller.seekToGlobalPosition(
                        currentChapter.start + value,
                      ),
                      elapsed: _formatTime(chapterElapsed / speed),
                      total: _formatTime(chapterDuration / speed),
                    ),
                  if (showChapterTime && showBookTime)
                    const SizedBox(height: 16),
                  if (showBookTime)
                    _ProgressSection(
                      label: showChapterTime ? 'Book' : null,
                      value: position.clamp(0, duration),
                      max: duration,
                      onChanged: controller.seekToGlobalPosition,
                      elapsed: _formatTime(position / speed),
                      total: _formatTime(duration / speed),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Speed sits at the left edge and bookmarks at the right —
              // both in their own [Expanded]/[Align] so the trio in the
              // middle stays truly centered on screen regardless of how
              // wide either side item is (a plain centered Row would
              // instead center the whole group, drifting the trio off
              // center whenever the two sides differ in width).
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _SpeedSelector(onChanged: controller.setSpeed),
                ),
              ),
              IconButton(
                iconSize: 36,
                icon: const Icon(Icons.replay_30),
                onPressed: controller.jumpBackward,
              ),
              const SizedBox(width: 16),
              PlaybackLoadingBadge(
                isLoading: isConnecting,
                child: IconButton(
                  iconSize: 56,
                  icon: Icon(
                    isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                  ),
                  onPressed: isConnecting
                      ? null
                      : () {
                          if (settings.hapticFeedbackEnabled) {
                            HapticFeedback.lightImpact();
                          }
                          isPlaying ? controller.pause() : controller.resume();
                        },
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                iconSize: 36,
                icon: const Icon(Icons.forward_30),
                onPressed: controller.jumpForward,
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: canBookmark
                      ? IconButton(
                          iconSize: 32,
                          icon: Icon(
                            bookmarks.isNotEmpty
                                ? Icons.bookmark
                                : Icons.bookmark_border,
                          ),
                          tooltip: 'Bookmarks',
                          onPressed: () => _showBookmarksSheet(context, item),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
          if (hasChapters || hasTracks) ...[
            const SizedBox(height: 24),
            // Collapsed by default — the list can be long (a 53-chapter
            // book fills the screen many times over) and most listeners
            // only open it to jump somewhere specific, not to browse it on
            // every visit to Now Playing.
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: hasChapters && hasTracks
                  ? Center(
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
                  : Text(
                      showChapters ? 'Chapters' : 'Tracks',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
              children: [
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
            ),
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

  void _showBookmarksSheet(BuildContext context, LibraryItemDetail item) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Consumer(
          builder: (context, ref, _) {
            final bookmarksAsync = ref.watch(bookmarksProvider(item.id));
            final bookmarks = bookmarksAsync.valueOrNull ?? const <Bookmark>[];
            final controller = ref.read(playbackControllerProvider.notifier);
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text('Bookmarks'),
                ),
                if (bookmarksAsync.isLoading && bookmarks.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (bookmarks.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Text('No bookmarks yet'),
                  )
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.4,
                    ),
                    child: ListView(
                      shrinkWrap: true,
                      children: bookmarks.map((bookmark) {
                        return ListTile(
                          leading: const Icon(Icons.bookmark),
                          title: Text(bookmark.title),
                          subtitle: Text(_formatTime(bookmark.time)),
                          onTap: () {
                            controller.seekToGlobalPosition(bookmark.time);
                            Navigator.pop(context);
                          },
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Delete bookmark',
                            onPressed: () =>
                                _deleteBookmark(context, item, bookmark),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ListTile(
                  leading: const Icon(Icons.add),
                  title: const Text('Add bookmark at current position'),
                  onTap: () => _addBookmark(context, item),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// PLAN.md Phase 5.8. Mirrors the reference app: defaults the note to a
  /// formatted current date/time so a listener can always just tap Add
  /// without typing anything, but lets them override it first.
  Future<void> _addBookmark(BuildContext context, LibraryItemDetail item) async {
    final position = ref.read(playbackPositionProvider).valueOrNull ?? 0.0;
    final defaultTitle = DateFormat.yMMMd().add_Hm().format(DateTime.now());
    final textController = TextEditingController(text: defaultTitle);
    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Bookmark'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Note'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(textController.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (title == null) return;
    try {
      await ref
          .read(bookmarkRepositoryProvider)
          .createBookmark(
            libraryItemId: item.id,
            time: position,
            title: title.trim().isEmpty ? defaultTitle : title.trim(),
          );
      ref.invalidate(bookmarksProvider(item.id));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to add bookmark')));
    }
  }

  Future<void> _deleteBookmark(
    BuildContext context,
    LibraryItemDetail item,
    Bookmark bookmark,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete bookmark?'),
        content: Text('This removes "${bookmark.title}" from the server.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(bookmarkRepositoryProvider)
          .deleteBookmark(libraryItemId: item.id, time: bookmark.time);
      ref.invalidate(bookmarksProvider(item.id));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete bookmark')),
      );
    }
  }
}

/// A seek [Slider] scoped to either the current chapter or the whole book,
/// with its elapsed/total pair underneath and an optional small caption
/// above (only used when both chapter and book progress are showing at
/// once — a single bar stays unlabeled, matching how this looked before the
/// per-mode split existed). One of these renders per enabled time-display
/// mode (PLAN.md Phase 5.5), so turning on "Chapter" and "Book" together
/// shows two independently-scoped progress bars instead of one book-wide
/// bar with two text rows.
class _ProgressSection extends StatelessWidget {
  const _ProgressSection({
    required this.value,
    required this.max,
    required this.onChanged,
    required this.elapsed,
    required this.total,
    this.label,
  });

  final double value;
  final double max;
  final ValueChanged<double> onChanged;
  final String elapsed;
  final String total;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final label = this.label;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(label, style: Theme.of(context).textTheme.labelSmall),
          ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          ),
          child: Slider(value: value, max: max, onChanged: onChanged),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text(elapsed), Text(total)],
          ),
        ),
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
