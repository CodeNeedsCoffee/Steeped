import '../linking/read_along.dart';
import '../linking/read_along_window.dart';
import 'package:flutter/material.dart';
import '../linking/linked_read_action.dart';
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
import 'data/playback_speed.dart';
import 'data/sleep_timer_duration.dart';
import 'discard_progress_dialog.dart';
import 'sync_failed_badge.dart';
import 'state/playback_controller.dart';
import 'time_display_mode_selector.dart';
import '../../l10n/l10n.dart';

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
enum _OverflowAction {
  sleepTimer,
  timeDisplay,
  markFinished,
  markNotFinished,
  discardProgress,
}

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
    final queue = ref.watch(playQueueProvider);
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
          tooltip: context.l10n.close,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          const SyncFailedBadge(),
          LinkedReadAction(audio: item),
          if (queue != null)
            IconButton(
              icon: const Icon(Icons.queue_music),
              tooltip: context.l10n.queue,
              onPressed: () => _showQueueSheet(context),
            ),
          IconButton(
            icon: Icon(
              sleepRemaining != null ? Icons.bedtime : Icons.bedtime_outlined,
            ),
            tooltip: sleepRemaining != null
                ? context.l10n.sleepTimerTooltipActive(
                    _formatTime(sleepRemaining.inSeconds.toDouble()),
                  )
                : context.l10n.sleepTimerTooltip,
            onPressed: () => _showSleepTimerSheet(context, ref, settings),
          ),
          IconButton(
            icon: const Icon(Icons.timer_outlined),
            tooltip: context.l10n.timeDisplayTooltip,
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
                case _OverflowAction.discardProgress:
                  confirmAndDiscardProgress(
                    context,
                    ref,
                    libraryItemId: item.id,
                    episodeId: item.episodeId,
                    title: item.title,
                  ).then((done) {
                    if (done && context.mounted)
                      Navigator.of(context).maybePop();
                  });
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _OverflowAction.sleepTimer,
                child: Text(context.l10n.sleepTimer),
              ),
              PopupMenuItem(
                value: _OverflowAction.timeDisplay,
                child: Text(context.l10n.timeDisplayMenu),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: _OverflowAction.markFinished,
                child: Text(context.l10n.markAsFinished),
              ),
              PopupMenuItem(
                value: _OverflowAction.markNotFinished,
                child: Text(context.l10n.markAsNotFinished),
              ),
              PopupMenuItem(
                value: _OverflowAction.discardProgress,
                child: Text(context.l10n.discardProgressMenu),
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
          if (currentChapter != null && currentChapter.title.isNotEmpty) ...[
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                currentChapter.title,
                textAlign: TextAlign.center,
                maxLines: 1,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
          if (ref.watch(readAlongOpenProvider)) ReadAlongWindow(audio: item),
          const _SleepTimerChip(),
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
                      label: showBookTime ? context.l10n.chapterLabel : null,
                      value: chapterElapsed,
                      max: chapterMax,
                      onSeek: (value) => controller.seekToGlobalPosition(
                        currentChapter.start + value,
                      ),
                      formatElapsed: (value) => _formatTime(value / speed),
                      total: _formatTime(chapterDuration / speed),
                    ),
                  if (showChapterTime && showBookTime)
                    const SizedBox(height: 16),
                  if (showBookTime)
                    _ProgressSection(
                      label: showChapterTime ? context.l10n.bookLabel : null,
                      value: position.clamp(0, duration),
                      max: duration,
                      onSeek: controller.seekToGlobalPosition,
                      formatElapsed: (value) => _formatTime(value / speed),
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
                  child: _SpeedSelector(
                    // `playbackSpeedProvider` maps over `playbackState`,
                    // which hasn't emitted before the first player event —
                    // falling back to the persisted setting stops a user
                    // whose saved speed is 1.3 from briefly seeing 1x.
                    currentSpeed:
                        ref.watch(playbackSpeedProvider).valueOrNull ??
                        settings.playbackSpeed,
                    onChanged: controller.setSpeed,
                  ),
                ),
              ),
              IconButton(
                tooltip: context.l10n.rewindSeconds(settings.jumpBackSeconds),
                iconSize: 36,
                icon: const Icon(Icons.replay),
                onPressed: controller.jumpBackward,
              ),
              const SizedBox(width: 16),
              PlaybackLoadingBadge(
                isLoading: isConnecting,
                child: IconButton(
                  tooltip: isPlaying ? context.l10n.pause : context.l10n.play,
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
                tooltip: context.l10n.forwardSeconds(
                  settings.jumpForwardSeconds,
                ),
                iconSize: 36,
                icon: Transform.flip(
                  flipX: true,
                  child: const Icon(Icons.replay),
                ),
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
                          tooltip: context.l10n.bookmarks,
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
                        segments: [
                          ButtonSegment(
                            value: _TrackListMode.chapters,
                            label: Text(context.l10n.chapters),
                          ),
                          ButtonSegment(
                            value: _TrackListMode.tracks,
                            label: Text(context.l10n.tracks),
                          ),
                        ],
                        selected: {_listMode},
                        onSelectionChanged: (s) =>
                            setState(() => _listMode = s.first),
                      ),
                    )
                  : Text(
                      showChapters
                          ? context.l10n.chapters
                          : context.l10n.tracks,
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
                      title: Text(
                        track.title ?? context.l10n.trackNumber(entry.key + 1),
                      ),
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
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.timeDisplayMenu),
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
    final chapterMinutesLeft = controller.chapterMinutesLeft();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _SleepTimerSheet(
        initialMinutes: settings.sleepTimerDefaultMinutes,
        isActive: isActive,
        chapterMinutesLeft: chapterMinutesLeft,
        onStart: (minutes) =>
            controller.startSleepTimer(Duration(minutes: minutes)),
        onCancel: controller.cancelSleepTimer,
      ),
    );
  }

  /// LIBRARY_PLAN.md L7: the playlist/collection being played through.
  void _showQueueSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Consumer(
        builder: (sheetContext, ref, _) {
          final queue = ref.watch(playQueueProvider);
          final current = ref.watch(currentPlaybackItemProvider);
          if (queue == null)
            return SizedBox(
              height: 120,
              child: Center(child: Text(context.l10n.queueFinished)),
            );
          return SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * 0.6,
            child: Column(
              children: [
                ListTile(
                  title: Text(context.l10n.queueNamed(queue.name)),
                  trailing: TextButton(
                    onPressed: () {
                      ref.read(playQueueProvider.notifier).state = null;
                      Navigator.of(sheetContext).pop();
                    },
                    child: Text(context.l10n.clear),
                  ),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    itemCount: queue.items.length,
                    onReorder: (a, b) {
                      final items = [...queue.items];
                      if (b > a) b -= 1;
                      items.insert(b, items.removeAt(a));
                      ref.read(playQueueProvider.notifier).state = queue
                          .copyWith(items: items);
                    },
                    itemBuilder: (context, i) {
                      final it = queue.items[i];
                      final isCurrent = current?.downloadId == it.downloadId;
                      return ListTile(
                        key: ValueKey('${it.downloadId}#$i'),
                        selected: isCurrent,
                        leading: Icon(
                          isCurrent ? Icons.equalizer : Icons.music_note,
                        ),
                        title: Text(
                          it.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: isCurrent
                            ? null
                            : () => ref
                                  .read(playbackControllerProvider.notifier)
                                  .playItem(it.libraryItemId),
                        trailing: Padding(
                          padding: const EdgeInsets.only(right: 32),
                          child: IconButton(
                            tooltip: context.l10n.removeFromQueue,
                            icon: const Icon(Icons.close),
                            onPressed: isCurrent
                                ? null
                                : () =>
                                      ref
                                          .read(playQueueProvider.notifier)
                                          .state = queue.copyWith(
                                        items: [...queue.items]..removeAt(i),
                                      ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
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
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(context.l10n.bookmarks),
                ),
                if (bookmarksAsync.isLoading && bookmarks.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (bookmarks.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(context.l10n.noBookmarksYet),
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
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                tooltip: context.l10n.rename,
                                onPressed: () =>
                                    _renameBookmark(context, item, bookmark),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                tooltip: context.l10n.deleteBookmarkTooltip,
                                onPressed: () =>
                                    _deleteBookmark(context, item, bookmark),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ListTile(
                  leading: const Icon(Icons.add),
                  title: Text(context.l10n.addBookmarkAtCurrentPosition),
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
  Future<void> _addBookmark(
    BuildContext context,
    LibraryItemDetail item,
  ) async {
    final position = ref.read(playbackPositionProvider).valueOrNull ?? 0.0;
    final defaultTitle = DateFormat.yMMMd().add_Hm().format(DateTime.now());
    final textController = TextEditingController(text: defaultTitle);
    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.addBookmark),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: InputDecoration(labelText: context.l10n.note),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(textController.text),
            child: Text(context.l10n.add),
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
      ).showSnackBar(SnackBar(content: Text(context.l10n.failedToAddBookmark)));
    }
  }

  Future<void> _renameBookmark(
    BuildContext context,
    LibraryItemDetail item,
    Bookmark bookmark,
  ) async {
    final textController = TextEditingController(text: bookmark.title);
    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.rename),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: InputDecoration(labelText: context.l10n.note),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(textController.text.trim()),
            child: Text(context.l10n.save),
          ),
        ],
      ),
    );
    if (title == null || title.isEmpty || title == bookmark.title) return;
    try {
      await ref
          .read(bookmarkRepositoryProvider)
          .renameBookmark(
            libraryItemId: item.id,
            time: bookmark.time,
            title: title,
          );
      ref.invalidate(bookmarksProvider(item.id));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.failedToAddBookmark)),
      );
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
        title: Text(context.l10n.deleteBookmarkTitle),
        content: Text(context.l10n.thisRemovesFromTheServer(bookmark.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.l10n.delete),
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
        SnackBar(content: Text(context.l10n.failedToDeleteBookmark)),
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
///
/// Bug fix 2026-09-22 (evan: seek bar "bounces around a lot back and forth"
/// while dragging). The old version was stateless and wired the `Slider`'s
/// `value` straight to the live playback-position stream, with `onChanged`
/// (fired on *every frame* of the drag) issuing a real network seek each
/// time. A streamed seek doesn't complete instantly, so the position stream
/// kept emitting the pre-seek position mid-drag, snapping the thumb back
/// under the user's finger — and the dozens of overlapping seeks dispatched
/// during one drag gesture could resolve out of order, landing on whichever
/// one's position event happened to arrive last rather than where the user
/// actually released. Now the thumb (and the elapsed-time label) tracks a
/// local [_dragValue] while dragging, completely decoupled from the live
/// stream, and exactly one real seek is issued on release.
class _ProgressSection extends StatefulWidget {
  const _ProgressSection({
    required this.value,
    required this.max,
    required this.onSeek,
    required this.formatElapsed,
    required this.total,
    this.label,
  });

  final double value;
  final double max;
  final ValueChanged<double> onSeek;
  final String Function(double value) formatElapsed;
  final String total;
  final String? label;

  @override
  State<_ProgressSection> createState() => _ProgressSectionState();
}

class _ProgressSectionState extends State<_ProgressSection> {
  /// Non-null only while the user has a finger on the slider. Read in
  /// preference to [_ProgressSection.value] so mid-drag rebuilds (the live
  /// stream still ticking in the background) never fight the drag gesture.
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final label = widget.label;
    final displayValue = _dragValue ?? widget.value;
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
          child: Slider(
            value: displayValue,
            max: widget.max,
            onChangeStart: (value) => setState(() => _dragValue = value),
            onChanged: (value) => setState(() => _dragValue = value),
            onChangeEnd: (value) {
              setState(() => _dragValue = null);
              widget.onSeek(value);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(widget.formatElapsed(displayValue)),
              Text(widget.total),
            ],
          ),
        ),
      ],
    );
  }
}

/// Driven entirely by [currentSpeed] (the live `playbackSpeedProvider`, via
/// the caller) rather than its own local state -- it used to default to a
/// hardcoded 1.0 on every build, which never reflected a speed persisted
/// from a previous session (or changed elsewhere, e.g. a future remote/car
/// control) until the user picked a new value.
///
/// Was a [DropdownButton] over a fixed 0.25 grid, which couldn't express
/// speeds like 1.1 or 1.3 -- and, because `DropdownButton` asserts its value
/// matches exactly one item, would have thrown outright once any off-grid
/// speed was in effect. Now a button opening [_SpeedSheet].
class _SpeedSelector extends StatelessWidget {
  const _SpeedSelector({required this.currentSpeed, required this.onChanged});

  final double currentSpeed;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => Padding(
          // Lifts the sheet above the keyboard while the value is typed.
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: _SpeedSheet(initialSpeed: currentSpeed, onChanged: onChanged),
        ),
      ),
      // Trimmed from the default button padding so the label gets as much of
      // this [Expanded] slot as possible before any scaling kicks in.
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      // Sized to sit visually level with the 32-36px transport icons either
      // side of it -- at default button text size the speed read as a stray
      // label rather than a peer control.
      //
      // This sits in an [Expanded], so on a narrow screen (or at a large
      // display-font setting) the slot can be thinner than the label: a
      // four-character value like "1.25x" then wrapped its trailing "x"
      // onto a second line. Scaling down keeps it on one line at whatever
      // size fits, rather than reflowing or clipping.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          formatPlaybackSpeed(currentSpeed),
          maxLines: 1,
          softWrap: false,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    );
  }
}

/// Playback-speed editor: coarse/fine steppers, a typed value, and presets.
/// Every change applies immediately rather than on a confirm button, so the
/// effect is audible while adjusting.
class _SpeedSheet extends StatefulWidget {
  const _SpeedSheet({required this.initialSpeed, required this.onChanged});

  final double initialSpeed;
  final ValueChanged<double> onChanged;

  @override
  State<_SpeedSheet> createState() => _SpeedSheetState();
}

class _SpeedSheetState extends State<_SpeedSheet> {
  late double _speed = normalizePlaybackSpeed(widget.initialSpeed);
  final _inputController = TextEditingController();
  String? _inputError;

  /// The typed-value field stays collapsed by default -- steppers and
  /// presets cover almost every adjustment, so showing a text field and
  /// keyboard affordance permanently just crowds the sheet.
  bool _showExactInput = false;

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  /// Local state drives the readout so steppers feel instant; the caller
  /// persists and the live provider catches up on the next player event.
  void _apply(double speed) {
    setState(() {
      _speed = speed;
      _inputError = null;
    });
    widget.onChanged(speed);
  }

  void _applyTypedValue() {
    final parsed = parsePlaybackSpeed(_inputController.text);
    if (parsed == null) {
      setState(
        () => _inputError = context.l10n.speedInputError(
          minPlaybackSpeed,
          maxPlaybackSpeed,
        ),
      );
      return;
    }
    _inputController.clear();
    FocusScope.of(context).unfocus();
    _apply(parsed);
    // Collapse again once a value lands, returning the sheet to its compact
    // form rather than leaving an empty field and the keyboard behind.
    setState(() => _showExactInput = false);
  }

  void _toggleExactInput() {
    setState(() {
      _showExactInput = !_showExactInput;
      if (!_showExactInput) {
        _inputController.clear();
        _inputError = null;
      }
    });
    if (!_showExactInput) FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.playbackSpeed,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            // Matching [Expanded]s either side keep the speed itself dead
            // centre; a plain centred Row would centre the text *and* the
            // pencil as one group, pushing the number off to the left. Same
            // trick the transport row above uses for its own centre trio.
            Row(
              children: [
                const Expanded(child: SizedBox.shrink()),
                Text(
                  formatPlaybackSpeed(_speed),
                  style: theme.textTheme.displaySmall,
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: _toggleExactInput,
                      tooltip: _showExactInput
                          ? context.l10n.hideExactSpeed
                          : context.l10n.enterExactSpeed,
                      isSelected: _showExactInput,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final delta in [-0.25, -0.1, 0.1, 0.25]) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: OutlinedButton(
                      // Disabled at the bounds so the button visibly stops
                      // instead of silently no-opping.
                      onPressed: stepPlaybackSpeed(_speed, delta) == _speed
                          ? null
                          : () => _apply(stepPlaybackSpeed(_speed, delta)),
                      child: Text('${delta > 0 ? '+' : '−'}${delta.abs()}'),
                    ),
                  ),
                ],
              ],
            ),
            if (_showExactInput) ...[
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      // Revealed on demand, so focus it straight away rather
                      // than making the reveal a two-tap affair.
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _applyTypedValue(),
                      decoration: InputDecoration(
                        labelText: context.l10n.exactSpeed,
                        hintText: formatPlaybackSpeed(_speed),
                        errorText: _inputError,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: FilledButton(
                      onPressed: _applyTypedValue,
                      child: Text(context.l10n.setLabel),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                for (final preset in playbackSpeedPresets)
                  ChoiceChip(
                    label: Text(formatPlaybackSpeed(preset)),
                    selected: _speed == preset,
                    onSelected: (_) => _apply(preset),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _speed == 1.0 ? null : () => _apply(1.0),
              child: Text(context.l10n.resetTo1x),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sleep-timer picker: a minutes slider with presets. Nothing applies until
/// "Start timer" -- a timer that began on every tweak would be running
/// before it was set. "End of chapter" fills the slider with the time left
/// in the chapter; the timer still starts from "Start timer".
class _SleepTimerSheet extends StatefulWidget {
  const _SleepTimerSheet({
    required this.initialMinutes,
    required this.isActive,
    required this.chapterMinutesLeft,
    required this.onStart,
    required this.onCancel,
  });

  final int initialMinutes;
  final bool isActive;

  /// Whole minutes (rounded up) to the end of the current chapter, or null
  /// when the book has no chapters.
  final int? chapterMinutesLeft;
  final ValueChanged<int> onStart;
  final VoidCallback onCancel;

  @override
  State<_SleepTimerSheet> createState() => _SleepTimerSheetState();
}

class _SleepTimerSheetState extends State<_SleepTimerSheet> {
  static const _sliderMax = 240;

  late int _minutes = _clamp(widget.initialMinutes);

  static int _clamp(int minutes) =>
      normalizeSleepMinutes(minutes).clamp(minSleepMinutes, _sliderMax);

  void _finish(VoidCallback action) {
    action();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chapterLeft = widget.chapterMinutesLeft;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.l10n.sleepTimer, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              formatSleepMinutes(_minutes),
              style: theme.textTheme.displaySmall,
            ),
            Slider(
              value: _minutes.toDouble(),
              min: minSleepMinutes.toDouble(),
              max: _sliderMax.toDouble(),
              divisions: _sliderMax - minSleepMinutes,
              label: formatSleepMinutes(_minutes),
              onChanged: (v) => setState(() => _minutes = v.round()),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                for (final preset in {
                  ...sleepTimerPresets,
                  widget.initialMinutes,
                }.where((m) => m <= _sliderMax).toList()..sort())
                  ChoiceChip(
                    label: Text(formatSleepMinutes(preset)),
                    selected: _minutes == preset,
                    onSelected: (_) => setState(() => _minutes = preset),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (chapterLeft != null)
              TextButton.icon(
                onPressed: () => setState(() => _minutes = _clamp(chapterLeft)),
                icon: const Icon(Icons.bookmark_outline),
                label: Text(context.l10n.endOfChapter),
              ),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _finish(() => widget.onStart(_minutes)),
                icon: const Icon(Icons.bedtime_outlined),
                label: Text(context.l10n.startTimer),
              ),
            ),
            if (widget.isActive)
              TextButton.icon(
                onPressed: () => _finish(widget.onCancel),
                icon: const Icon(Icons.cancel_outlined),
                label: Text(context.l10n.cancelTimer),
              ),
          ],
        ),
      ),
    );
  }
}

/// Countdown with quick "+N min" / restart controls (QOL_PLAN B5).
class _SleepTimerChip extends ConsumerWidget {
  const _SleepTimerChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remaining = ref.watch(sleepTimerRemainingProvider);
    final fired = ref.watch(sleepTimerFiredProvider);
    final endOfChapter = ref.watch(sleepTimerEndOfChapterProvider);
    if (remaining == null && !fired) return const SizedBox.shrink();
    final settings =
        ref.watch(appSettingsProvider).valueOrNull ?? const AppSettings();
    final controller = ref.read(playbackControllerProvider.notifier);
    final s = remaining?.inSeconds ?? 0;
    final clock = '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          Chip(
            avatar: const Icon(Icons.bedtime_outlined, size: 18),
            label: Text(
              fired
                  ? context.l10n.sleepTimerEnded
                  : endOfChapter
                  ? context.l10n.chapterEndsIn(clock)
                  : context.l10n.sleepIn(clock),
            ),
          ),
          if (fired)
            ActionChip(
              label: Text(context.l10n.restart),
              onPressed: controller.restartSleepTimer,
            ),
          ActionChip(
            label: Text(context.l10n.min(settings.sleepExtendMinutes)),
            onPressed: controller.extendSleepTimer,
          ),
          if (fired)
            IconButton(
              tooltip: context.l10n.dismiss,
              icon: const Icon(Icons.close, size: 18),
              onPressed: controller.cancelSleepTimer,
            ),
        ],
      ),
    );
  }
}
