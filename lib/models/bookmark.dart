/// A saved position within a book (PLAN.md Phase 5.8), matching the real
/// Audiobookshelf server's `/api/me/item/:id/bookmark` shape: `time` is the
/// raw global position in seconds (not chapter-relative, not scaled by
/// playback speed) and doubles as the bookmark's identity — the server has
/// no separate bookmark id, so create/update/delete all key off `time`.
class Bookmark {
  const Bookmark({
    required this.libraryItemId,
    required this.time,
    required this.title,
  });

  final String libraryItemId;
  final double time;
  final String title;

  factory Bookmark.fromJson(Map<String, dynamic> json) {
    return Bookmark(
      libraryItemId: json['libraryItemId'] as String,
      time: (json['time'] as num).toDouble(),
      title: json['title'] as String? ?? '',
    );
  }
}
