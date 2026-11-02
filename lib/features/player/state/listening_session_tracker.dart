import 'dart:async';

import 'package:dio/dio.dart';

import '../data/listening_session_repository.dart';

/// Reports listening time to the server as a real listening session, which is
/// what History, the daily totals and the streak are built from (the
/// sessionless progress PATCH only records the position).
///
/// Flow per item: [attach] -> [setPlaying] as playback starts/stops ->
/// [tick] on each sync interval and pause -> [end] when it stops, finishes or
/// another item replaces it. Everything is best effort: a failure keeps the
/// unsent seconds and retries on the next tick, and time that can't be
/// delivered is queued durably (`/api/session/local`) rather than lost.
///
/// `timeListened` is wall-clock time spent playing, so seeking adds nothing
/// and 2x speed counts real seconds, matching the official client.
class ListeningSessionTracker {
  ListeningSessionTracker({
    required this.apiOf,
    required this.pendingOf,
    required this.hasNetwork,
    required this.activeProfileId,
    this.onSessionEnded,
    this.onLiveKeyChanged,
    DateTime Function()? now,
    String Function()? newKey,
  }) : _now = now ?? DateTime.now,
       _newKey = newKey ?? _defaultKey;

  /// Resolved on each use: the active profile (and so the Dio) can change.
  final ListeningSessionRepository Function() apiOf;
  final PendingListeningSessionRepository Function() pendingOf;
  final Future<bool> Function() hasNetwork;
  final String Function() activeProfileId;

  /// Called after a session is closed (or queued), so stats can refresh.
  final void Function()? onSessionEnded;

  /// The queue key of the session being tracked right now (null when none).
  /// The queue uploader skips it: this tracker is still adding to that row.
  final void Function(String? key)? onLiveKeyChanged;

  final DateTime Function() _now;
  final String Function() _newKey;

  static int _counter = 0;
  static String _defaultKey() =>
      'steeped-${DateTime.now().microsecondsSinceEpoch}-${_counter++}';

  _Active? _active;
  bool _playing = false;

  /// Starts tracking [item], first closing whatever was tracked before.
  /// Idempotent for the item already being tracked (play/resume calls it).
  /// [itemKey] is the downloadId; [ownerProfileId] is the profile whose
  /// server owns the item.
  void attach(
    SessionItem item, {
    required String itemKey,
    required String ownerProfileId,
  }) {
    final current = _active;
    if (current != null && current.itemKey == itemKey) {
      current.item = item;
      return;
    }
    if (current != null) unawaited(_flush(current, close: true));
    final next = _Active(
      item: item,
      itemKey: itemKey,
      ownerProfileId: ownerProfileId,
      localKey: _newKey(),
      startedAt: _now(),
    );
    if (_playing) next.playingSince = _now();
    _active = next;
    onLiveKeyChanged?.call(next.localKey);
  }

  /// Mirrors the player's `playing` flag; time only accrues while true.
  void setPlaying(bool playing) {
    if (playing == _playing) return;
    _playing = playing;
    final a = _active;
    if (a == null) return;
    _collect(a);
    a.playingSince = playing ? _now() : null;
  }

  /// Sync interval / pause: sends the unsent time without closing.
  Future<void> tick(double currentTime) {
    final a = _active;
    if (a == null) return Future.value();
    a.currentTime = currentTime;
    return _flush(a, close: false);
  }

  /// Closes the active session (stop, finish).
  Future<void> end(double currentTime) {
    final a = _active;
    if (a == null) return Future.value();
    a.currentTime = currentTime;
    _active = null;
    onLiveKeyChanged?.call(null);
    return _flush(a, close: true);
  }

  void _collect(_Active a) {
    final since = a.playingSince;
    if (since == null) return;
    final now = _now();
    a.unsent += now.difference(since).inMilliseconds / 1000.0;
    a.playingSince = now;
  }

  Future<void> _flush(_Active a, {required bool close}) async {
    _collect(a);
    if (!close && a.unsent < 1) return;
    if (a.busy) {
      // A flush is already awaiting the network; closing must still happen.
      if (close) a.closeRequested = true;
      return;
    }
    a.busy = true;
    try {
      await _deliver(a, close: close);
      while (a.closeRequested) {
        a.closeRequested = false;
        _collect(a);
        await _deliver(a, close: true);
      }
    } finally {
      a.busy = false;
    }
    if (close) onSessionEnded?.call();
  }

  Future<void> _deliver(_Active a, {required bool close}) async {
    final item = a.item;
    final seconds = a.unsent;
    final position = a.currentTime;

    if (a.ownerProfileId == activeProfileId() && await hasNetwork()) {
      try {
        if (a.sessionId == null && (seconds >= 1 || !close)) {
          a.sessionId = await apiOf().open(item);
        }
        final id = a.sessionId;
        if (id != null) {
          if (close) {
            await apiOf().close(
              id,
              timeListened: seconds,
              currentTime: position,
              duration: item.duration,
            );
          } else {
            await apiOf().sync(
              id,
              timeListened: seconds,
              currentTime: position,
              duration: item.duration,
            );
          }
          // Time that accrued while the call was in flight stays unsent.
          a.unsent -= seconds;
          await pendingOf().remove(a.localKey);
          return;
        }
        if (seconds < 1) return;
      } on DioException catch (e) {
        // The server forgot the session (restart, cleanup): open a fresh one
        // next time and keep the time.
        if (e.response?.statusCode == 404) a.sessionId = null;
      } catch (_) {
        // Fall through to the durable queue.
      }
    }
    if (a.unsent >= 1) await _persist(a);
  }

  Future<void> _persist(_Active a) {
    return pendingOf().upsert(
      sessionKey: a.localKey,
      item: a.item,
      currentTime: a.currentTime,
      timeListening: a.unsent,
      startedAt: a.startedAt,
      ownerProfileId: a.ownerProfileId,
    );
  }
}

class _Active {
  _Active({
    required this.item,
    required this.itemKey,
    required this.ownerProfileId,
    required this.localKey,
    required this.startedAt,
  });

  SessionItem item;
  final String itemKey;
  final String ownerProfileId;
  final String localKey;
  final DateTime startedAt;

  String? sessionId;
  double unsent = 0;
  double currentTime = 0;
  DateTime? playingSince;
  bool busy = false;
  bool closeRequested = false;
}
