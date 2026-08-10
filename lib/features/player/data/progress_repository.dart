import 'dart:async';

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

  /// Bug fix 2026-08-05 (evan: playback staggering, with `receive timeout`
  /// progress-sync errors in the log). The shared [Dio] allows 15s to connect
  /// and 30s to receive, which is a sane ceiling for fetching a library page
  /// but wildly wrong for a fire-and-forget position ping: a sync that hangs
  /// for 45s straddles three of [PlaybackController]'s 15s sync ticks, so a
  /// slow server accumulated several simultaneous stalled requests, all
  /// competing with the audio stream for that same server's attention. This
  /// is a *progress ping* — a few dozen bytes each way. If it hasn't landed
  /// in 10s it isn't going to, and the durable queue (PLAN.md Phase 6.7)
  /// already guarantees nothing is lost by giving up early.
  static const _deadline = Duration(seconds: 10);

  /// [Options.receiveTimeout] alone can't enforce [_deadline] — `connectTimeout`
  /// is a [BaseOptions]-only setting, so a request stuck in DNS resolution or a
  /// TCP handshake (exactly the `Failed host lookup` case in the log) would
  /// still hold its socket for the client-wide 15s. Cancelling is what actually
  /// tears the request down at the deadline rather than just reporting on it.
  Future<void> _patchProgress(String path, Map<String, Object> data) async {
    final cancelToken = CancelToken();
    final deadline = Timer(
      _deadline,
      () => cancelToken.cancel('progress sync exceeded ${_deadline.inSeconds}s'),
    );
    try {
      await _dio.patch<void>(
        path,
        data: data,
        cancelToken: cancelToken,
        options: Options(sendTimeout: _deadline, receiveTimeout: _deadline),
      );
    } finally {
      deadline.cancel();
    }
  }

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
    await _patchProgress(path, data);
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
    await _patchProgress('/api/me/progress/$libraryItemId', data);
  }
}
