import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../models/media_progress.dart';
import '../../../models/recent_episode.dart';
import '../data/podcast_repository.dart';

final podcastRepositoryProvider = Provider<PodcastRepository>((ref) {
  return PodcastRepository(ref.watch(dioProvider));
});

/// Per-episode progress for a podcast, keyed by `episodeId`. Kept separate
/// from the item detail (which comes from the shared item endpoint) so it can
/// refresh on its own after playback without refetching the whole podcast.
final episodeProgressProvider = FutureProvider.autoDispose
    .family<Map<String, MediaProgress>, String>((ref, podcastItemId) async {
      return ref
          .read(podcastRepositoryProvider)
          .fetchEpisodeProgress(podcastItemId);
    });

/// PLAN.md Phase 7.6: recent-episodes feed for a podcast library.
final recentEpisodesProvider = FutureProvider.autoDispose
    .family<List<RecentEpisode>, String>((ref, libraryId) async {
      return ref.read(podcastRepositoryProvider).fetchRecentEpisodes(libraryId);
    });
