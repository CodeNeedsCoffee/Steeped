import 'package:dio/dio.dart';

import '../../../models/media_progress.dart';
import '../../../models/recent_episode.dart';

/// PLAN.md Phase 7. Podcast-specific reads layered on the shared library
/// endpoints: per-episode progress (for played/unplayed/incomplete state)
/// and the library-wide recent-episodes feed.
class PodcastRepository {
  const PodcastRepository(this._dio);

  final Dio _dio;

  /// Per-episode progress for one podcast, keyed by `episodeId`. The expanded
  /// item response doesn't inline episode progress, so it comes from the
  /// user's `mediaProgress` list (`GET /api/me`) filtered to this podcast —
  /// mirroring how the reference app keeps progress in its user store.
  Future<Map<String, MediaProgress>> fetchEpisodeProgress(
    String podcastItemId,
  ) async {
    final response = await _dio.get<Map<String, dynamic>>('/api/me');
    final list =
        (response.data?['mediaProgress'] as List<dynamic>?) ?? const [];
    final result = <String, MediaProgress>{};
    for (final raw in list.cast<Map<String, dynamic>>()) {
      if (raw['libraryItemId'] != podcastItemId) continue;
      final episodeId = raw['episodeId'] as String?;
      if (episodeId == null) continue;
      result[episodeId] = MediaProgress.fromJson(raw);
    }
    return result;
  }

  /// PLAN.md Phase 7.6: newest episodes across a podcast library.
  Future<List<RecentEpisode>> fetchRecentEpisodes(
    String libraryId, {
    int limit = 25,
    int page = 0,
  }) async {
    final response = await _dio.get<dynamic>(
      '/api/libraries/$libraryId/recent-episodes',
      queryParameters: {'limit': limit, 'page': page},
    );
    // Confirmed live against evan's server (2026-07-31): `{ episodes: [...],
    // limit, page }`. Still tolerant of a bare top-level array, just in case
    // a server version differs.
    final data = response.data;
    final list = data is Map<String, dynamic>
        ? (data['episodes'] as List<dynamic>?) ?? const []
        : data is List
        ? data
        : const [];
    return list
        .cast<Map<String, dynamic>>()
        .map(RecentEpisode.tryFromJson)
        .whereType<RecentEpisode>()
        .toList();
  }
}
