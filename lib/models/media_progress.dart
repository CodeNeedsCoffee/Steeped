/// `userMediaProgress` on an expanded item response (`?include=progress`).
/// See `~/Code/audiobookshelf/server/objects/user/MediaProgress.js`.
///
/// [ebookLocation]/[ebookProgress] are the ebook-reading analogue of
/// [currentTime]/[progress] — confirmed live against evan's real server
/// (2026-07-31): for an ebook-only item, `currentTime`/`duration`/`progress`
/// all sit at 0 and the real position lives in `ebookLocation` (an EPUB CFI
/// string) with `ebookProgress` as the 0..1 fraction. Audio items don't set
/// these two fields.
class MediaProgress {
  const MediaProgress({
    required this.progress,
    required this.currentTime,
    required this.isFinished,
    this.ebookLocation,
    this.ebookProgress,
  });

  factory MediaProgress.fromJson(Map<String, dynamic> json) {
    return MediaProgress(
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      currentTime: (json['currentTime'] as num?)?.toDouble() ?? 0,
      isFinished: json['isFinished'] as bool? ?? false,
      ebookLocation: json['ebookLocation'] as String?,
      ebookProgress: (json['ebookProgress'] as num?)?.toDouble(),
    );
  }

  /// 0..1 fraction listened.
  final double progress;
  final double currentTime;
  final bool isFinished;
  final String? ebookLocation;
  final double? ebookProgress;
}
