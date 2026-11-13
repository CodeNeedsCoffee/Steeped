import 'package:flutter/material.dart';
import '../../core/utils/html_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/cover_image_url.dart';
import '../../core/storage/app_database.dart';
import '../../models/library_item_detail.dart';
import '../../widgets/cover_image.dart';
import '../auth/state/session_controller.dart';
import '../auth/state/session_state.dart';
import '../auth/state/permission_providers.dart';
import '../linking/linked_book_section.dart';
import 'library_actions.dart';
import 'series_detail_screen.dart';
import '../downloads/state/download_controller.dart';
import '../player/mini_player.dart';
import '../player/now_playing_navigation.dart';
import '../player/state/playback_controller.dart';
import '../podcasts/podcast_detail_view.dart';
import 'state/library_providers.dart';
import '../../l10n/l10n.dart';
import '../../core/utils/format_duration.dart';

/// PLAN.md Phase 4.8: item detail screen. Play (Phase 5) and Download
/// (Phase 6) are real; "Read" and "Add to Playlist" remain stubs (ebook
/// reading is Milestone 2 Phase 8; playlists are deferred, see 4.5 note).
class ItemDetailScreen extends ConsumerWidget {
  const ItemDetailScreen({required this.itemId, super.key});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    final detailAsync = ref.watch(itemDetailProvider(itemId));

    // This page stays open under Now Playing, so its copy of the progress goes
    // stale while you listen (a rewound "Finished" book kept saying Finished).
    // Refetch when Now Playing closes, when this book starts, and just after
    // playback stops (the position is synced on pause, hence the short delay).
    void refreshSoon(Duration delay) {
      Future.delayed(delay, () {
        if (context.mounted) ref.invalidate(itemDetailProvider(itemId));
      });
    }

    ref.listen(nowPlayingOpenProvider, (previous, open) {
      if (previous == true && !open) refreshSoon(const Duration(seconds: 1));
    });
    ref.listen(currentPlaybackItemProvider.select((i) => i?.downloadId), (
      previous,
      id,
    ) {
      if (id != previous) refreshSoon(const Duration(seconds: 3));
    });
    ref.listen(isPlayingProvider, (previous, next) {
      if (previous?.valueOrNull == true && next.valueOrNull == false) {
        refreshSoon(const Duration(seconds: 2));
      }
    });
    final (serverUrl, token) = switch (session) {
      SessionAuthenticated(:final serverUrl, :final user) => (
        serverUrl,
        user.effectiveToken,
      ),
      _ => (null, null),
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text(''),
        actions: [
          if (detailAsync.valueOrNull case final item?)
            if (!item.isPodcast)
              IconButton(
                tooltip: context.l10n.moreActions,
                icon: const Icon(Icons.more_vert),
                onPressed: () => showItemQuickActions(
                  context,
                  ref,
                  item.toLibraryItem(),
                  canDiscardProgress: item.progress != null,
                ),
              ),
        ],
      ),
      body: detailAsync.when(
        // Keep showing the page while a refetch runs (no spinner flash).
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(context.l10n.failedToLoad(error))),
        data: (item) => serverUrl == null
            ? const SizedBox.shrink()
            : item.isPodcast
            ? PodcastDetailBody(item: item, serverUrl: serverUrl, token: token)
            : _ItemDetailBody(item: item, serverUrl: serverUrl, token: token),
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}

class _ItemDetailBody extends ConsumerWidget {
  const _ItemDetailBody({
    required this.item,
    required this.serverUrl,
    required this.token,
  });

  final LibraryItemDetail item;
  final String serverUrl;
  final String? token;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final isLoadingPlay = ref.watch(playbackLoadingIdProvider) == item.id;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: CoverImage(
            url: coverImageUrl(
              serverUrl: serverUrl,
              itemId: item.id,
              token: token,
              updatedAt: item.updatedAt,
            ),
            width: 200,
            height: 200,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          item.title,
          style: textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        if (item.subtitle != null)
          Text(
            item.subtitle!,
            style: textTheme.titleSmall,
            textAlign: TextAlign.center,
          ),
        if (item.authors.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              alignment: WrapAlignment.center,
              children: [
                for (final a in item.authors)
                  InkWell(
                    onTap: () => context.push('/author/${a.id}'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        a.name,
                        style: textTheme.bodyMedium?.copyWith(
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        if (item.series.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              alignment: WrapAlignment.center,
              children: [
                for (final s in item.series)
                  InkWell(
                    onTap: () => context.push(
                      seriesLocation(
                        s.id,
                        libraryId: item.libraryId,
                        name: s.name,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        s.label,
                        style: textTheme.bodySmall?.copyWith(
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        if (item.series.isNotEmpty &&
            item.libraryId != null &&
            ref.watch(canDownloadProvider))
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _DownloadSeriesButton(
              item: item,
              serverUrl: serverUrl,
              token: token,
            ),
          ),
        if (item.progress != null) ...[
          const SizedBox(height: 12),
          LinearProgressIndicator(value: _displayProgressFraction(item)),
          Text(
            item.progress!.isFinished
                ? context.l10n.finished
                : _progressSummary(context, item),
            style: textTheme.labelSmall,
          ),
        ],
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!item.isEbookOnly)
            FilledButton.icon(
              onPressed: item.tracks.isEmpty || isLoadingPlay
                  ? null
                  : () async {
                      await ref
                          .read(playbackControllerProvider.notifier)
                          .playItem(item.id);
                      if (context.mounted &&
                          ref.read(currentPlaybackItemProvider)?.id ==
                              item.id) {
                        openNowPlaying(context, ref);
                      }
                    },
              icon: isLoadingPlay
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(context.l10n.play),
            ),
            if (item.hasEbook) ...[
              if (!item.isEbookOnly) const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => _openReader(context, item),
                icon: const Icon(Icons.menu_book),
                label: Text(
                  _ebookPercent(item) >= 100
                      ? context.l10n.readAgain
                      : _ebookPercent(item) > 0
                          ? context.l10n.readingPercent(_ebookPercent(item))
                          : context.l10n.read,
                ),
              ),
            ],
            if (item.tracks.isNotEmpty && ref.watch(canDownloadProvider)) ...[
              const SizedBox(width: 12),
              _DownloadButton(item: item, serverUrl: serverUrl, token: token),
            ],
          ],
        ),
        LinkedBookSection(item: item),
        if (item.genres.isNotEmpty) ...[
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: item.genres.map((g) => Chip(label: Text(g))).toList(),
          ),
        ],
        if (item.narrators.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            context.l10n.narratedBy(item.narrators.join(', ')),
            textAlign: TextAlign.center,
          ),
        ],
        if (!item.isPodcast) ...[
          const SizedBox(height: 8),
          Text(
            [
              if (item.duration != null) formatDurationText(context.l10n, item.duration!),
              if (item.chapters.isNotEmpty)
                context.l10n.chaptersCount(item.chapters.length),
              // A scraped year of 0 means "unknown", not the year zero.
              if (item.publishedYear != null &&
                  item.publishedYear!.trim().isNotEmpty &&
                  item.publishedYear!.trim() != '0')
                item.publishedYear!,
            ].join(' · '),
            textAlign: TextAlign.center,
            style: textTheme.bodySmall,
          ),
        ],
        if (item.description != null) ...[
          const SizedBox(height: 20),
          Text(plainTextFromHtml(item.description!), style: textTheme.bodyMedium),
        ],
      ],
    );
  }

  /// PLAN.md Phase 8: routes to the right reader by `ebookFormat` — epub
  /// (8.1), pdf (8.3), cbz (8.4). cbr has no pure-Dart decoder available
  /// (see `EbookFile.isSupported`), so it surfaces a message instead of a
  /// broken reader.
  void _openReader(BuildContext context, LibraryItemDetail item) {
    final ebookFile = item.ebookFile;
    if (ebookFile == null) return;
    if (!ebookFile.isSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.isnTSupportedYetNo(ebookFile.format),
          ),
        ),
      );
      return;
    }
    final path = ebookFile.isEpub
        ? '/reader/epub/${item.id}'
        : ebookFile.isPdf
        ? '/reader/pdf/${item.id}'
        : '/reader/comic/${item.id}';
    context.push(path);
  }


  /// The server's `progress` fraction field isn't recomputed by the
  /// sessionless progress-sync PATCH we use (5.9) — only `currentTime`/
  /// `duration` are, confirmed by inspecting a raw server response where
  /// `currentTime` had advanced but `progress` hadn't moved at all.
  /// Computing the fraction client-side keeps this display consistent with
  /// what's actually used to resume playback, instead of silently drifting
  /// stale relative to it.
  /// Whole-percent ebook progress, 0 when unstarted. A book marked finished with
  /// no reading position reads as 100.
  int _ebookPercent(LibraryItemDetail item) {
    final p = item.progress;
    if (p == null) return 0;
    final fraction = p.ebookProgress ?? 0;
    // A finished book that is being re-read keeps isFinished on the server, so
    // trust the reading position once there is one.
    if (p.isFinished && fraction == 0) return 100;
    return (fraction * 100).round().clamp(0, 100);
  }

  double _displayProgressFraction(LibraryItemDetail item) {
    final progress = item.progress;
    if (progress == null) return 0;
    // Ebook-only items carry their position in `ebookProgress`; the server's
    // `progress`/currentTime stay at 0 for them.
    if (item.tracks.isEmpty && item.hasEbook) {
      return (progress.ebookProgress ?? 0).clamp(0.0, 1.0);
    }
    final duration = item.duration;
    if (duration == null || duration <= 0) return progress.progress;
    return (progress.currentTime / duration).clamp(0, 1);
  }

  /// "$X% complete", plus "$Yh $Zm left" for audiobooks specifically --
  /// gated on [LibraryItemDetail.tracks] rather than just `duration != null`
  /// because an ebook-only item's `currentTime`/`duration` both sit at 0
  /// (see [MediaProgress]'s doc comment: its real reading position lives in
  /// `ebookProgress`/`ebookLocation` instead), so there's no time-based
  /// countdown to show for those.
  String _progressSummary(BuildContext context, LibraryItemDetail item) {
    final percent = (_displayProgressFraction(item) * 100).round();
    final duration = item.duration;
    if (item.tracks.isEmpty || duration == null || duration <= 0) {
      return context.l10n.percentComplete(percent);
    }
    final remaining = (duration - item.progress!.currentTime)
        .clamp(0.0, duration)
        .toDouble();
    return context.l10n.percentCompleteTimeLeft(
      percent,
      formatDurationText(context.l10n, remaining),
    );
  }
}

/// PLAN.md Phase 6.2: "download series" without the full series-browse UI
/// (4.5, still deferred) — one tap queues every not-yet-downloaded book in
/// the item's first series membership.
class _DownloadSeriesButton extends ConsumerStatefulWidget {
  const _DownloadSeriesButton({
    required this.item,
    required this.serverUrl,
    required this.token,
  });

  final LibraryItemDetail item;
  final String serverUrl;
  final String? token;

  @override
  ConsumerState<_DownloadSeriesButton> createState() =>
      _DownloadSeriesButtonState();
}

class _DownloadSeriesButtonState extends ConsumerState<_DownloadSeriesButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final series = widget.item.series.first;
    return TextButton.icon(
      onPressed: _busy
          ? null
          : () async {
              setState(() => _busy = true);
              final messenger = ScaffoldMessenger.of(context);
              try {
                final queued = await ref
                    .read(downloadControllerProvider.notifier)
                    .downloadSeries(
                      libraryId: widget.item.libraryId!,
                      seriesId: series.id,
                      serverUrl: widget.serverUrl,
                      token: widget.token,
                    );
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      queued == 0
                          ? context.l10n.allBooksAlreadyDownloaded(series.name)
                          : context.l10n.downloadingBooksFromSeries(
                              queued,
                              series.name,
                            ),
                    ),
                  ),
                );
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            },
      icon: _busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.download_outlined, size: 18),
      label: Text(context.l10n.downloadSeries(series.name)),
    );
  }
}

/// PLAN.md Phase 6.1: not-downloaded / downloading (with progress) /
/// downloaded (with delete) states.
class _DownloadButton extends ConsumerWidget {
  const _DownloadButton({
    required this.item,
    required this.serverUrl,
    required this.token,
  });

  final LibraryItemDetail item;
  final String serverUrl;
  final String? token;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloads = ref.watch(downloadsListProvider).valueOrNull ?? const [];
    DownloadedItem? existing;
    for (final d in downloads) {
      if (d.itemId == item.id) {
        existing = d;
        break;
      }
    }

    if (existing == null) {
      return OutlinedButton.icon(
        onPressed: () => ref
            .read(downloadControllerProvider.notifier)
            .download(item: item, serverUrl: serverUrl, token: token),
        icon: const Icon(Icons.download_outlined),
        label: Text(context.l10n.download),
      );
    }

    if (existing.status == 'complete') {
      return OutlinedButton.icon(
        onPressed: () =>
            ref.read(downloadControllerProvider.notifier).delete(item.id),
        icon: const Icon(Icons.download_done),
        label: Text(context.l10n.downloaded),
      );
    }

    final progress = ref.watch(downloadProgressProvider)[item.id];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 130,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 4),
              Text(
                progress == null
                    ? context.l10n.downloadingEllipsis
                    : '${(progress * 100).round()}%',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close),
          tooltip: context.l10n.cancelDownload,
          onPressed: () =>
              ref.read(downloadControllerProvider.notifier).cancel(item.id),
        ),
      ],
    );
  }
}
