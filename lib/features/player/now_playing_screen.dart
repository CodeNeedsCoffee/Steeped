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
import 'data/playback_speed.dart';
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
                iconSize: 36,
                icon: const Icon(Icons.fast_rewind),
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
                icon: const Icon(Icons.fast_forward),
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
        () => _inputError =
            'Enter a number between $minPlaybackSpeed and $maxPlaybackSpeed.',
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
            Text('Playback Speed', style: theme.textTheme.titleMedium),
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
                          ? 'Hide exact speed'
                          : 'Enter exact speed',
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
                      child: Text(
                        '${delta > 0 ? '+' : '−'}${delta.abs()}',
                      ),
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
                        labelText: 'Exact speed',
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
                      child: const Text('Set'),
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
              child: const Text('Reset to 1x'),
            ),
          ],
        ),
      ),
    );
  }
}
