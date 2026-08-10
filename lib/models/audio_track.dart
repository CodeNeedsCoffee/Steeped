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
    this.title,
  });

  factory AudioTrack.fromJson(Map<String, dynamic> json) {
    return AudioTrack(
      index: json['index'] as int? ?? 0,
      contentUrl: json['contentUrl'] as String? ?? '',
      duration: (json['duration'] as num?)?.toDouble() ?? 0,
      startOffset: (json['startOffset'] as num?)?.toDouble() ?? 0,
      // `Book.getTracklist()` sets this to the audio file's own filename
      // (e.g. "01 - Chapter One.mp3") — not always present (a locally
      // rebuilt offline/download item doesn't carry it), so callers fall
      // back to a generic "Track N" label rather than an empty string.
      title: json['title'] as String?,
    );
  }

  final int index;
  final String contentUrl; // relative, e.g. /api/items/:id/file/:ino
  final double duration;
  final double startOffset;
  final String? title;

  double get endOffset => startOffset + duration;
}
