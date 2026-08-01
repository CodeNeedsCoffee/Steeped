import 'package:dio/dio.dart';

import '../../../models/listening_session.dart';
import '../../../models/listening_stats.dart';

class ListeningSessionsPage {
  const ListeningSessionsPage({
    required this.sessions,
    required this.total,
    required this.page,
    required this.numPages,
  });

  final List<ListeningSession> sessions;
  final int total;
  final int page;
  final int numPages;
}

/// PLAN.md Phase 9.4 (Stats) / 9.7 (History). Both endpoints confirmed live
/// against evan's real server (2026-07-31) — `/api/me/stats` (the more
/// obvious guess) 404s; the real one is `/api/me/listening-stats`.
class StatsRepository {
  const StatsRepository(this._dio);

  final Dio _dio;

  Future<ListeningStats> fetchListeningStats() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/me/listening-stats',
    );
    return ListeningStats.fromJson(response.data ?? const {});
  }

  /// Not part of `/api/me/listening-stats` (which has time-per-item, not a
  /// finished flag) — reuses the same `/api/me` `mediaProgress` list already
  /// confirmed live in Phase 7 for episode progress.
  Future<int> fetchFinishedItemsCount() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/me');
    final list =
        (response.data?['mediaProgress'] as List<dynamic>?) ?? const [];
    return list
        .cast<Map<String, dynamic>>()
        .where((p) => p['isFinished'] == true)
        .length;
  }

  Future<ListeningSessionsPage> fetchListeningSessions({
    required int page,
    int itemsPerPage = 20,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/me/listening-sessions',
      queryParameters: {'page': page, 'itemsPerPage': itemsPerPage},
    );
    final data = response.data ?? const {};
    final sessions = (data['sessions'] as List<dynamic>?) ?? const [];
    return ListeningSessionsPage(
      sessions: sessions
          .cast<Map<String, dynamic>>()
          .map(ListeningSession.fromJson)
          .toList(),
      total: data['total'] as int? ?? 0,
      page: data['page'] as int? ?? page,
      numPages: data['numPages'] as int? ?? 1,
    );
  }
}
