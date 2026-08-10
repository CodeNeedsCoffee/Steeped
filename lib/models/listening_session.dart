/// One entry of `GET /api/me/listening-sessions` (`sessions[]`) or
/// `GET /api/me/listening-stats` (`recentSessions[]`) — confirmed live
/// against evan's real server (2026-07-31), same shape in both places.
class ListeningSession {
  const ListeningSession({
    required this.id,
    required this.libraryItemId,
    required this.episodeId,
    required this.mediaType,
    required this.displayTitle,
    required this.displayAuthor,
    required this.coverPath,
    required this.duration,
    required this.timeListening,
    required this.date,
    required this.updatedAt,
  });

  factory ListeningSession.fromJson(Map<String, dynamic> json) {
    return ListeningSession(
      id: json['id'] as String? ?? '',
      libraryItemId: json['libraryItemId'] as String? ?? '',
      episodeId: json['episodeId'] as String?,
      mediaType: json['mediaType'] as String? ?? 'book',
      displayTitle: json['displayTitle'] as String? ?? 'Untitled',
      displayAuthor: json['displayAuthor'] as String?,
      coverPath: json['coverPath'] as String?,
      duration: (json['duration'] as num?)?.toDouble() ?? 0,
      timeListening: (json['timeListening'] as num?)?.toDouble() ?? 0,
      date: json['date'] as String? ?? '',
      updatedAt: json['updatedAt'] as int? ?? 0,
    );
  }

  final String id;
  final String libraryItemId;
  final String? episodeId;
  final String mediaType;
  final String displayTitle;
  final String? displayAuthor;
  final String? coverPath;
  final double duration;
  final double timeListening;
  final String date;
  final int updatedAt;
}
