import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:intl/intl.dart';

import '../../../core/storage/app_database.dart';

/// What the app needs to describe an item to the server's listening stats.
class SessionItem {
  const SessionItem({
    required this.libraryItemId,
    this.episodeId,
    required this.title,
    this.author,
    required this.duration,
  });

  final String libraryItemId;
  final String? episodeId;
  final String title;
  final String? author;
  final double duration;
}

/// Audiobookshelf listening sessions: what feeds History, the daily totals
/// behind the stats charts and the streak. Separate from the sessionless
/// `PATCH /api/me/progress` that keeps the *position* (`ProgressRepository`).
///
/// Confirmed live against the demo server (2026-10-30): `/play` -> `sync` ->
/// `close` creates a session and raises `listening-stats` for today.
class ListeningSessionRepository {
  const ListeningSessionRepository(this._dio);

  final Dio _dio;

  /// Same reasoning as `ProgressRepository`: these are small fire-and-forget
  /// pings and must never hold a socket (or playback) hostage.
  static const _deadline = Duration(seconds: 10);

  static const _deviceInfo = {'clientName': 'Steeped'};

  Future<T> _withDeadline<T>(
    Future<T> Function(CancelToken token, Options options) call,
  ) async {
    final token = CancelToken();
    final timer = Timer(
      _deadline,
      () => token.cancel('session call timed out'),
    );
    try {
      return await call(
        token,
        Options(sendTimeout: _deadline, receiveTimeout: _deadline),
      );
    } finally {
      timer.cancel();
    }
  }

  /// Opens a session and returns its id. Only the id is used: audio is still
  /// loaded from our own URLs, so the returned tracks are ignored.
  Future<String> open(SessionItem item) async {
    final path = item.episodeId == null
        ? '/api/items/${item.libraryItemId}/play'
        : '/api/items/${item.libraryItemId}/play/${item.episodeId}';
    final res = await _withDeadline(
      (token, options) => _dio.post<Map<String, dynamic>>(
        path,
        data: {
          'deviceInfo': _deviceInfo,
          'forceDirectPlay': true,
          'forceTranscode': false,
          'supportedMimeTypes': const [
            'audio/flac',
            'audio/mpeg',
            'audio/mp4',
            'audio/ogg',
            'audio/aac',
            'audio/x-m4b',
          ],
        },
        cancelToken: token,
        options: options,
      ),
    );
    final id = res.data?['id'] as String?;
    if (id == null) throw StateError('/play returned no session id');
    return id;
  }

  Future<void> sync(
    String sessionId, {
    required double timeListened,
    required double currentTime,
    required double duration,
  }) => _send(
    '/api/session/$sessionId/sync',
    timeListened,
    currentTime,
    duration,
  );

  Future<void> close(
    String sessionId, {
    required double timeListened,
    required double currentTime,
    required double duration,
  }) => _send(
    '/api/session/$sessionId/close',
    timeListened,
    currentTime,
    duration,
  );

  Future<void> _send(
    String path,
    double timeListened,
    double currentTime,
    double duration,
  ) => _withDeadline(
    (token, options) => _dio.post<void>(
      path,
      data: {
        'timeListened': timeListened,
        'currentTime': currentTime,
        'duration': duration,
      },
      cancelToken: token,
      options: options,
    ),
  );

  /// Uploads time that was listened offline (or whose sync failed) as one
  /// finished session.
  Future<void> uploadLocal(PendingListeningSession row) async {
    final started = row.startedAt;
    await _withDeadline(
      (token, options) => _dio.post<void>(
        '/api/session/local',
        data: {
          'id': row.sessionKey,
          'libraryItemId': row.libraryItemId,
          'episodeId': row.episodeId,
          'mediaType': row.episodeId == null ? 'book' : 'podcast',
          'displayTitle': row.displayTitle,
          'displayAuthor': row.displayAuthor ?? '',
          'duration': row.duration,
          'currentTime': row.currentTime,
          'startTime': 0,
          'timeListening': row.timeListening,
          'playMethod': 3,
          'mediaPlayer': 'Steeped',
          'deviceInfo': _deviceInfo,
          'date': DateFormat('yyyy-MM-dd').format(started),
          'dayOfWeek': DateFormat('EEEE', 'en_US').format(started),
          'startedAt': started.millisecondsSinceEpoch,
          'updatedAt': row.updatedAt.millisecondsSinceEpoch,
        },
        cancelToken: token,
        options: options,
      ),
    );
  }
}

/// Durable queue for listening time that didn't reach the server. Rows are
/// keyed by a client-made id and upserted as the total grows, so a crash
/// loses at most one sync interval.
class PendingListeningSessionRepository {
  PendingListeningSessionRepository(this._db, {this.profileId = ''});

  final AppDatabase _db;

  /// The active profile, for [pending]. Rows are only uploaded while the
  /// profile that owns them is active.
  final String profileId;

  Future<void> upsert({
    required String sessionKey,
    required SessionItem item,
    required double currentTime,
    required double timeListening,
    required DateTime startedAt,
    required String ownerProfileId,
  }) {
    return _db
        .into(_db.pendingListeningSessions)
        .insertOnConflictUpdate(
          PendingListeningSessionsCompanion.insert(
            sessionKey: sessionKey,
            libraryItemId: item.libraryItemId,
            episodeId: Value(item.episodeId),
            displayTitle: item.title,
            displayAuthor: Value(item.author),
            duration: item.duration,
            currentTime: currentTime,
            timeListening: timeListening,
            startedAt: startedAt,
            updatedAt: DateTime.now(),
            profileId: Value(ownerProfileId),
          ),
        );
  }

  Future<void> remove(String sessionKey) => (_db.delete(
    _db.pendingListeningSessions,
  )..where((t) => t.sessionKey.equals(sessionKey))).go();

  Future<List<PendingListeningSession>> pending() => (_db.select(
    _db.pendingListeningSessions,
  )..where((t) => t.profileId.equals(profileId))).get();
}
