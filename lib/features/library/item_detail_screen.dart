import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/cover_image_url.dart';
import '../../core/storage/app_database.dart';
import '../../models/library_item_detail.dart';
import '../../widgets/cover_image.dart';
import '../auth/state/session_controller.dart';
import '../auth/state/session_state.dart';
import '../downloads/state/download_controller.dart';
import '../player/mini_player.dart';
import '../player/state/playback_controller.dart';
import '../podcasts/podcast_detail_view.dart';
import 'state/library_providers.dart';

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
    final (serverUrl, token) = switch (session) {
      SessionAuthenticated(:final serverUrl, :final user) => (
        serverUrl,
        user.effectiveToken,
      ),
      _ => (null, null),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('')),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load: $error')),
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
  const _ItemDetailBody({required this.item, required this.serverUrl, required this.token});

  final LibraryItemDetail item;
  final String serverUrl;
  final String? token;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
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
        Text(item.title, style: textTheme.headlineSmall, textAlign: TextAlign.center),
        if (item.subtitle != null)
          Text(item.subtitle!, style: textTheme.titleSmall, textAlign: TextAlign.center),
        if (item.authors.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              item.authorNames,
              style: textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
        if (item.series.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              item.series.map((s) => s.label).join(', '),
              style: textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
        if (item.series.isNotEmpty && item.libraryId != null)
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
                ? 'Finished'
                : '${(_displayProgressFraction(item) * 100).round()}% complete',
            style: textTheme.labelSmall,
          ),
        ],
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: item.tracks.isEmpty
                  ? null
                  : () {
                      ref
                          .read(playbackControllerProvider.notifier)
                          .playItem(item.id);
                      context.push('/now-playing');
                    },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Play'),
            ),
            if (item.hasEbook) ...[
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => _openReader(context, item),
                icon: const Icon(Icons.menu_book),
                label: const Text('Read'),
              ),
            ],
            if (item.tracks.isNotEmpty) ...[
              const SizedBox(width: 12),
              _DownloadButton(item: item, serverUrl: serverUrl, token: token),
            ],
          ],
        ),
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
          Text('Narrated by ${item.narrators.join(', ')}', textAlign: TextAlign.center),
        ],
        if (!item.isPodcast) ...[
          const SizedBox(height: 8),
          Text(
            [
              if (item.duration != null) _formatDuration(item.duration!),
              if (item.chapters.isNotEmpty) '${item.chapters.length} chapters',
              if (item.publishedYear != null) item.publishedYear!,
            ].join(' · '),
            textAlign: TextAlign.center,
            style: textTheme.bodySmall,
          ),
        ],
        if (item.description != null) ...[
          const SizedBox(height: 20),
          Text(item.description!, style: textTheme.bodyMedium),
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
            '.${ebookFile.format} isn\'t supported yet — no pure-Dart RAR decoder exists for CBR.',
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

  String _formatDuration(double seconds) {
    final totalMinutes = (seconds / 60).round();
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours == 0) return '${minutes}m';
    return '${hours}h ${minutes}m';
  }

  /// The server's `progress` fraction field isn't recomputed by the
  /// sessionless progress-sync PATCH we use (5.9) — only `currentTime`/
  /// `duration` are, confirmed by inspecting a raw server response where
  /// `currentTime` had advanced but `progress` hadn't moved at all.
  /// Computing the fraction client-side keeps this display consistent with
  /// what's actually used to resume playback, instead of silently drifting
  /// stale relative to it.
  double _displayProgressFraction(LibraryItemDetail item) {
    final progress = item.progress;
    if (progress == null) return 0;
    final duration = item.duration;
    if (duration == null || duration <= 0) return progress.progress;
    return (progress.currentTime / duration).clamp(0, 1);
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
                          ? 'Every book in "${series.name}" is already '
                                'downloaded.'
                          : 'Downloading $queued book'
                                '${queued == 1 ? '' : 's'} from '
                                '"${series.name}".',
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
      label: Text('Download series: ${series.name}'),
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
        label: const Text('Download'),
      );
    }

    if (existing.status == 'complete') {
      return OutlinedButton.icon(
        onPressed: () =>
            ref.read(downloadControllerProvider.notifier).delete(item.id),
        icon: const Icon(Icons.download_done),
        label: const Text('Downloaded'),
      );
    }

    final progress = ref.watch(downloadProgressProvider)[item.id];
    return SizedBox(
      width: 130,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(value: progress),
          const SizedBox(height: 4),
          Text(
            progress == null ? 'Downloading…' : '${(progress * 100).round()}%',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
