/// One entry of `media.tracks[]` on an expanded item response — see
/// `Book.getTracklist()` (`~/Code/audiobookshelf/server/models/Book.js:293-303`).
/// For a multi-file book, each track is a *separate* audio file; the server
/// does not concatenate them. `startOffset` is the cumulative duration of
/// all prior tracks, letting chapters (defined on one continuous virtual
/// timeline) be mapped onto `(trackIndex, offsetWithinTrack)` for seeking.
class AudioTrack {
  const AudioTrack({
    required this.index,
    required this.contentUrl,
    required this.duration,
    required this.startOffset,
  });

  factory AudioTrack.fromJson(Map<String, dynamic> json) {
    return AudioTrack(
      index: json['index'] as int? ?? 0,
      contentUrl: json['contentUrl'] as String? ?? '',
      duration: (json['duration'] as num?)?.toDouble() ?? 0,
      startOffset: (json['startOffset'] as num?)?.toDouble() ?? 0,
    );
  }

  final int index;
  final String contentUrl; // relative, e.g. /api/items/:id/file/:ino
  final double duration;
  final double startOffset;

  double get endOffset => startOffset + duration;
}
