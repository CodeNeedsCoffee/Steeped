import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/network/cover_image_url.dart';
import '../../models/library_item_detail.dart';
import '../../models/media_progress.dart';
import '../../models/podcast_episode.dart';
import '../../widgets/cover_image.dart';
import '../downloads/state/download_controller.dart';
import '../player/state/playback_controller.dart';
import 'state/podcast_providers.dart';

/// PLAN.md Phase 7.1/7.2/7.5: podcast detail — header + episode list with
/// per-episode played/in-progress/unplayed state, stream/download/delete.
/// Rendered by [ItemDetailScreen] in place of the book body when the item is
/// a podcast. Add-podcast (7.3) and server-side auto-download/delete (7.4,
/// delete-from-server) are deferred — see PLAN.md Phase 7 notes.
class PodcastDetailBody extends ConsumerWidget {
  const PodcastDetailBody({
    required this.item,
    required this.serverUrl,
    required this.token,
    super.key,
  });

  final LibraryItemDetail item;
  final String serverUrl;
  final String? token;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final progressByEpisode =
        ref.watch(episodeProgressProvider(item.id)).valueOrNull ?? const {};

    final episodes = _sortedWithProgress(item.episodes, progressByEpisode);
    final incomplete = episodes.where((e) => !e.isFinished).length;

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
            width: 180,
            height: 180,
          ),
        ),
        const SizedBox(height: 16),
        Text(item.title, style: textTheme.headlineSmall, textAlign: TextAlign.center),
        if (item.authors.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              item.authorNames,
              style: textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
        if (item.genres.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: item.genres.map((g) => Chip(label: Text(g))).toList(),
          ),
        ],
        if (item.description != null) ...[
          const SizedBox(height: 16),
          Text(item.description!, style: textTheme.bodyMedium),
        ],
        const SizedBox(height: 24),
        Text(
          episodes.isEmpty
              ? 'Episodes'
              : incomplete > 0
              ? '${episodes.length} episodes · $incomplete incomplete'
              : '${episodes.length} episodes',
          style: textTheme.titleMedium,
        ),
        const Divider(),
        if (episodes.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('No episodes yet.')),
          )
        else
          ...episodes.map(
            (e) => _EpisodeTile(
              podcast: item,
              episode: e,
              serverUrl: serverUrl,
              token: token,
            ),
          ),
      ],
    );
  }

  List<PodcastEpisode> _sortedWithProgress(
    List<PodcastEpisode> episodes,
    Map<String, MediaProgress> progressByEpisode,
  ) {
    final merged = episodes
        .map((e) => e.copyWith(progress: progressByEpisode[e.id]))
        .toList();
    merged.sort((a, b) {
      final pa = a.publishedAt;
      final pb = b.publishedAt;
      if (pa != null && pb != null) return pb.compareTo(pa);
      if (pa != null) return -1;
      if (pb != null) return 1;
      return b.index.compareTo(a.index);
    });
    return merged;
  }
}

class _EpisodeTile extends ConsumerWidget {
  const _EpisodeTile({
    required this.podcast,
    required this.episode,
    required this.serverUrl,
    required this.token,
  });

  final LibraryItemDetail podcast;
  final PodcastEpisode episode;
  final String serverUrl;
  final String? token;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtitle = [
      if (episode.publishedAt != null) _formatDate(episode.publishedAt!),
      if (episode.duration != null) _formatDuration(episode.duration!),
      if (episode.isFinished)
        'Finished'
      else if (episode.isInProgress && episode.duration != null)
        '${((episode.progress!.currentTime / episode.duration!) * 100).round()}% played',
    ].join(' · ');

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: _StateIcon(episode: episode),
      title: Text(episode.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: _EpisodeDownloadButton(
        podcast: podcast,
        episode: episode,
        serverUrl: serverUrl,
        token: token,
      ),
      onTap: episode.audioTrack == null
          ? null
          : () async {
              await ref
                  .read(playbackControllerProvider.notifier)
                  .playEpisode(podcast, episode);
              if (context.mounted) context.push('/now-playing');
            },
    );
  }

  String _formatDate(int millis) {
    final date = DateTime.fromMillisecondsSinceEpoch(millis);
    return DateFormat.yMMMd().format(date);
  }

  String _formatDuration(double seconds) {
    final totalMinutes = (seconds / 60).round();
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours == 0) return '${minutes}m';
    return '${hours}h ${minutes}m';
  }
}

class _StateIcon extends StatelessWidget {
  const _StateIcon({required this.episode});

  final PodcastEpisode episode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (episode.isFinished) {
      return Icon(Icons.check_circle, color: scheme.primary);
    }
    if (episode.isInProgress) {
      return Icon(Icons.play_circle_outline, color: scheme.primary);
    }
    return Icon(Icons.circle_outlined, color: scheme.outline);
  }
}

/// Per-episode mirror of the book download button on [ItemDetailScreen]:
/// not-downloaded / downloading (progress) / downloaded (delete).
class _EpisodeDownloadButton extends ConsumerWidget {
  const _EpisodeDownloadButton({
    required this.podcast,
    required this.episode,
    required this.serverUrl,
    required this.token,
  });

  final LibraryItemDetail podcast;
  final PodcastEpisode episode;
  final String serverUrl;
  final String? token;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadId = '${podcast.id}::${episode.id}';
    final downloads = ref.watch(downloadsListProvider).valueOrNull ?? const [];
    final existing = downloads.where((d) => d.itemId == downloadId).firstOrNull;

    if (existing == null) {
      return IconButton(
        icon: const Icon(Icons.download_outlined),
        tooltip: 'Download episode',
        onPressed: episode.audioTrack == null
            ? null
            : () => ref
                  .read(downloadControllerProvider.notifier)
                  .downloadEpisode(
                    podcast: podcast,
                    episode: episode,
                    serverUrl: serverUrl,
                    token: token,
                  ),
      );
    }

    if (existing.status == 'complete') {
      return IconButton(
        icon: const Icon(Icons.download_done),
        tooltip: 'Delete downloaded episode',
        onPressed: () =>
            ref.read(downloadControllerProvider.notifier).delete(downloadId),
      );
    }

    final progress = ref.watch(downloadProgressProvider)[downloadId];
    return SizedBox(
      width: 24,
      height: 24,
      child: CircularProgressIndicator(value: progress, strokeWidth: 2),
    );
  }
}
