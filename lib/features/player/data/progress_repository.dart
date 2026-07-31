import 'package:dio/dio.dart';

/// PLAN.md Phase 5.9/5.10. Uses the sessionless `PATCH /api/me/progress/:id`
/// endpoint (no `/play` session needed — see PLAN.md Phase 5 notes) for
/// both periodic progress sync and marking an item finished/not finished.
class ProgressRepository {
  const ProgressRepository(this._dio);

  final Dio _dio;

  Future<void> updateProgress({
    required String libraryItemId,
    required double currentTime,
    required double duration,
    bool? isFinished,
  }) async {
    final data = <String, Object>{
      'currentTime': currentTime,
      'duration': duration,
    };
    if (isFinished != null) data['isFinished'] = isFinished;
    await _dio.patch<void>('/api/me/progress/$libraryItemId', data: data);
  }
}
