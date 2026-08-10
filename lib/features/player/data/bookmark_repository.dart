import 'package:dio/dio.dart';

import '../../../models/bookmark.dart';

/// PLAN.md Phase 5.8. Bookmarks live on the server's `User` object, keyed by
/// `libraryItemId` + exact `time` (confirmed against real server source —
/// there's no separate bookmark id). Podcast episodes aren't supported here:
/// the server itself only keys bookmarks by `libraryItemId`, not per
/// episode (a TODO in its own source), so a per-episode bookmark would
/// silently show up against the whole podcast instead — [NowPlayingScreen]
/// hides the bookmark action for episodes and local-only media rather than
/// offer a feature that can't actually work correctly for them.
class BookmarkRepository {
  const BookmarkRepository(this._dio);

  final Dio _dio;

  Future<List<Bookmark>> fetchBookmarks(String libraryItemId) async {
    final response = await _dio.get<Map<String, dynamic>>('/api/me');

    // Extract the user's bookmarks array (defaults to empty list if null)
    final rawBookmarks = response.data?['bookmarks'] as List<dynamic>? ?? const [];

    // Filter for the matching libraryItemId and map to Bookmark objects
    return rawBookmarks
        .cast<Map<String, dynamic>>()
        .where((json) => json['libraryItemId'] == libraryItemId)
        .map(Bookmark.fromJson)
        .toList();
  }

  Future<void> createBookmark({
    required String libraryItemId,
    required double time,
    required String title,
  }) async {
    await _dio.post<void>(
      '/api/me/item/$libraryItemId/bookmark',
      data: {'time': time.round(), 'title': title},
    );
  }

  Future<void> deleteBookmark({
    required String libraryItemId,
    required double time,
  }) async {
    await _dio.delete<void>(
      '/api/me/item/$libraryItemId/bookmark/${time.round()}',
    );
  }
}
