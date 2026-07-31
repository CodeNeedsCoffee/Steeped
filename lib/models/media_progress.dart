/// `userMediaProgress` on an expanded item response (`?include=progress`).
/// See `~/Code/audiobookshelf/server/objects/user/MediaProgress.js`.
class MediaProgress {
  const MediaProgress({
    required this.progress,
    required this.currentTime,
    required this.isFinished,
  });

  factory MediaProgress.fromJson(Map<String, dynamic> json) {
    return MediaProgress(
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      currentTime: (json['currentTime'] as num?)?.toDouble() ?? 0,
      isFinished: json['isFinished'] as bool? ?? false,
    );
  }

  /// 0..1 fraction listened.
  final double progress;
  final double currentTime;
  final bool isFinished;
}
