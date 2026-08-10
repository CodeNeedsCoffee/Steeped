import 'audio_track.dart';
import 'media_progress.dart';

/// One entry of a podcast item's `media.episodes[]` on an expanded response
/// (`GET /api/items/:id?expanded=1`) — see
/// `~/Code/audiobookshelf/server/models/PodcastEpisode.js`
/// (`toOldJSONExpanded`). Unlike a multi-file book, a podcast episode is a
/// single audio file, so its [audioTrack] is one track with `startOffset` 0.
///
/// [progress] is not part of the item response — it's merged in from the
/// user's `mediaProgress` (keyed by `episodeId`) so the episode list can show
/// played / in-progress / unplayed state (PLAN.md Phase 7.2).
class PodcastEpisode {
  const PodcastEpisode({
    required this.id,
    required this.index,
    required this.season,
    required this.episode,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.pubDate,
    required this.publishedAt,
    required this.duration,
    required this.audioTrack,
    required this.progress,
  });

  /// [libraryItemId] is only needed for responses that carry a raw
  /// `audioFile` instead of a ready-made `audioTrack` (the recent-episodes
  /// feed does this) — it lets us synthesize the stream `contentUrl`.
  factory PodcastEpisode.fromJson(
    Map<String, dynamic> json, {
    String? libraryItemId,
  }) {
    final trackJson = json['audioTrack'] as Map<String, dynamic>?;
    final duration = (json['duration'] as num?)?.toDouble();
    AudioTrack? audioTrack;
    if (trackJson != null) {
      audioTrack = AudioTrack.fromJson(trackJson);
    } else {
      final audioFile = json['audioFile'] as Map<String, dynamic>?;
      final ino = audioFile?['ino'] as String?;
      if (ino != null && libraryItemId != null) {
        audioTrack = AudioTrack(
          index: json['index'] as int? ?? 1,
          contentUrl: '/api/items/$libraryItemId/file/$ino',
          duration: duration ?? 0,
          startOffset: 0,
        );
      }
    }
    return PodcastEpisode(
      id: json['id'] as String,
      index: json['index'] as int? ?? 0,
      season: json['season'] as String? ?? '',
      episode: json['episode'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled Episode',
      subtitle: json['subtitle'] as String?,
      description: json['description'] as String?,
      pubDate: json['pubDate'] as String?,
      publishedAt: json['publishedAt'] as int?,
      duration: duration,
      audioTrack: audioTrack,
      progress: null,
    );
  }

  final String id;
  final int index;
  final String season;
  final String episode;
  final String title;
  final String? subtitle;
  final String? description;
  final String? pubDate;
  final int? publishedAt; // epoch millis
  final double? duration; // seconds
  final AudioTrack? audioTrack;
  final MediaProgress? progress;

  bool get isFinished => progress?.isFinished ?? false;

  /// True once there's saved position past the very start but not finished —
  /// i.e. "incomplete" in the reference app's episode-state vocabulary.
  bool get isInProgress =>
      !isFinished && (progress?.currentTime ?? 0) > 0;

  PodcastEpisode copyWith({MediaProgress? progress}) {
    return PodcastEpisode(
      id: id,
      index: index,
      season: season,
      episode: episode,
      title: title,
      subtitle: subtitle,
      description: description,
      pubDate: pubDate,
      publishedAt: publishedAt,
      duration: duration,
      audioTrack: audioTrack,
      progress: progress ?? this.progress,
    );
  }
}
