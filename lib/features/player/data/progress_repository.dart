import 'package:dio/dio.dart';

/// PLAN.md Phase 5.9/5.10. Uses the sessionless `PATCH /api/me/progress/:id`
/// endpoint (no `/play` session needed — see PLAN.md Phase 5 notes) for
/// both periodic progress sync and marking an item finished/not finished.
///
/// A podcast episode syncs to the two-segment `PATCH
/// /api/me/progress/:libraryItemId/:episodeId` variant instead (PLAN.md
/// Phase 7) — otherwise identical.
class ProgressRepository {
  const ProgressRepository(this._dio);

  final Dio _dio;

  Future<void> updateProgress({
    required String libraryItemId,
    required double currentTime,
    required double duration,
    bool? isFinished,
    String? episodeId,
  }) async {
    final data = <String, Object>{
      'currentTime': currentTime,
      'duration': duration,
    };
    if (isFinished != null) data['isFinished'] = isFinished;
    final path = episodeId == null
        ? '/api/me/progress/$libraryItemId'
        : '/api/me/progress/$libraryItemId/$episodeId';
    await _dio.patch<void>(path, data: data);
  }

  /// PLAN.md Phase 8.1: ebook reading position sync. Confirmed live
  /// (2026-07-31) that the server tracks ebook position via `ebookLocation`
  /// (an EPUB CFI string) and `ebookProgress` (0..1 fraction) on the same
  /// progress object rather than `currentTime`/`duration` — same PATCH
  /// endpoint, different body shape.
  Future<void> updateEbookProgress({
    required String libraryItemId,
    required String ebookLocation,
    required double ebookProgress,
    bool? isFinished,
  }) async {
    final data = <String, Object>{
      'ebookLocation': ebookLocation,
      'ebookProgress': ebookProgress,
    };
    if (isFinished != null) data['isFinished'] = isFinished;
    await _dio.patch<void>('/api/me/progress/$libraryItemId', data: data);
  }
}
