import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/network/cover_image_url.dart';
import '../../models/recent_episode.dart';
import '../../widgets/cover_image.dart';
import '../auth/state/session_controller.dart';
import '../auth/state/session_state.dart';
import '../downloads/state/download_controller.dart';
import '../player/mini_player.dart';
import '../player/state/playback_controller.dart';
import 'state/podcast_providers.dart';

/// PLAN.md Phase 7.6: newest episodes across a podcast library, with play +
/// download-to-device. Server-source for the exact `/recent-episodes` shape
/// isn't on this machine, so parsing is tolerant (see [RecentEpisode]) and
/// this is a prime candidate for the on-device checkpoint to confirm.
class RecentEpisodesScreen extends ConsumerWidget {
  const RecentEpisodesScreen({required this.libraryId, super.key});

  final String libraryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    final episodesAsync = ref.watch(recentEpisodesProvider(libraryId));
    final (serverUrl, token) = switch (session) {
      SessionAuthenticated(:final serverUrl, :final user) => (
        serverUrl,
        user.effectiveToken,
      ),
      _ => (null, null),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Latest Episodes')),
      body: serverUrl == null
          ? const SizedBox.shrink()
          : episodesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('Failed to load: $error')),
              data: (episodes) {
                if (episodes.isEmpty) {
                  return const Center(child: Text('No recent episodes.'));
                }
                return RefreshIndicator(
                  onRefresh: () =>
                      ref.refresh(recentEpisodesProvider(libraryId).future),
                  child: ListView.builder(
                    itemCount: episodes.length,
                    itemBuilder: (context, index) => _RecentEpisodeTile(
                      entry: episodes[index],
                      serverUrl: serverUrl,
                      token: token,
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}

class _RecentEpisodeTile extends ConsumerWidget {
  const _RecentEpisodeTile({
    required this.entry,
    required this.serverUrl,
    required this.token,
  });

  final RecentEpisode entry;
  final String serverUrl;
  final String? token;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final episode = entry.episode;
    final downloadId = '${entry.podcastItemId}::${episode.id}';
    final downloads = ref.watch(downloadsListProvider).valueOrNull ?? const [];
    final isDownloaded = downloads.any(
      (d) => d.itemId == downloadId && d.status == 'complete',
    );

    final subtitle = [
      entry.podcastTitle,
      if (episode.publishedAt != null)
        DateFormat.yMMMd()
            .format(DateTime.fromMillisecondsSinceEpoch(episode.publishedAt!)),
    ].join(' · ');

    return ListTile(
      leading: CoverImage(
        url: coverImageUrl(
          serverUrl: serverUrl,
          itemId: entry.podcastItemId,
          token: token,
          updatedAt: entry.podcastUpdatedAt,
        ),
        width: 48,
        height: 48,
      ),
      title: Text(episode.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: IconButton(
        icon: Icon(
          isDownloaded ? Icons.download_done : Icons.download_outlined,
        ),
        tooltip: isDownloaded ? 'Downloaded' : 'Download episode',
        onPressed: isDownloaded
            ? null
            : () => ref
                  .read(downloadControllerProvider.notifier)
                  .downloadEpisode(
                    podcast: entry.podcastItem,
                    episode: episode,
                    serverUrl: serverUrl,
                    token: token,
                  ),
      ),
      onTap: () async {
        await ref
            .read(playbackControllerProvider.notifier)
            .playEpisode(entry.podcastItem, episode);
        if (context.mounted) context.push('/now-playing');
      },
    );
  }
}
