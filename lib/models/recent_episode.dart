import 'library_item_detail.dart';
import 'podcast_episode.dart';

/// One entry of `GET /api/libraries/:id/recent-episodes` (PLAN.md Phase 7.6).
/// Each entry is a podcast episode plus enough of its parent podcast to show
/// it in a list and hand off to [PlaybackController.playEpisode] — the parent
/// carries the cover/author while the episode carries the audio track.
///
/// The exact nesting of the parent-podcast fields varies by server version,
/// so parsing here is deliberately tolerant of a few shapes (`podcast`,
/// `libraryItem`, or a flat `libraryItemId`).
class RecentEpisode {
  const RecentEpisode({
    required this.podcastItemId,
    required this.podcastTitle,
    required this.podcastAuthor,
    required this.podcastUpdatedAt,
    required this.episode,
  });

  static RecentEpisode? tryFromJson(Map<String, dynamic> json) {
    final parent =
        (json['podcast'] as Map<String, dynamic>?) ??
        (json['libraryItem'] as Map<String, dynamic>?) ??
        const {};
    final parentMedia = (parent['media'] as Map<String, dynamic>?) ?? const {};
    final parentMeta =
        (parentMedia['metadata'] as Map<String, dynamic>?) ??
        (parent['metadata'] as Map<String, dynamic>?) ??
        const {};

    final podcastItemId =
        json['libraryItemId'] as String? ?? parent['id'] as String?;
    if (podcastItemId == null) return null;

    final episode = PodcastEpisode.fromJson(json, libraryItemId: podcastItemId);
    if (episode.audioTrack == null) return null;

    return RecentEpisode(
      podcastItemId: podcastItemId,
      podcastTitle: parentMeta['title'] as String? ?? 'Podcast',
      podcastAuthor: parentMeta['author'] as String?,
      podcastUpdatedAt:
          parent['updatedAt'] as int? ?? json['updatedAt'] as int? ?? 0,
      episode: episode,
    );
  }

  final String podcastItemId;
  final String podcastTitle;
  final String? podcastAuthor;
  final int podcastUpdatedAt;
  final PodcastEpisode episode;

  /// The minimal parent-podcast item [PlaybackController.playEpisode] needs.
  LibraryItemDetail get podcastItem => LibraryItemDetail(
    id: podcastItemId,
    mediaType: 'podcast',
    coverPath: null,
    updatedAt: podcastUpdatedAt,
    title: podcastTitle,
    subtitle: null,
    authors: podcastAuthor == null
        ? const []
        : [AuthorRef(id: '', name: podcastAuthor!)],
    narrators: const [],
    series: const [],
    genres: const [],
    description: null,
    publishedYear: null,
    duration: null,
    chapters: const [],
    hasEbook: false,
    progress: null,
    tracks: const [],
  );
}
