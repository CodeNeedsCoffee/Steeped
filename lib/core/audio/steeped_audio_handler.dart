import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../../models/audio_track.dart';
import '../../models/library_item_detail.dart';
import 'car_content_tree.dart';

/// PLAN.md Phase 5.1/5.3/5.4/5.12. Wraps a single `just_audio` [AudioPlayer]
/// with a gapless multi-source playlist (one child per [AudioTrack]) via
/// `setAudioSources` — multi-file books are NOT concatenated server-side
/// (confirmed against
/// `Book.getTracklist()`), so chapter seeking has to map a global (virtual,
/// continuous) timeline position onto `(trackIndex, offsetWithinTrack)`,
/// mirroring the reference app's `PlaybackSession.getCurrentTrackIndex` /
/// `seekPlayer`. `BaseAudioHandler` is what surfaces play/pause/seek to the
/// lock screen and notification (Phase 5.4) and keeps playback alive in the
/// background (5.3) via audio_service's Android foreground service.
///
/// Direct play only — no transcode negotiation (the `/play` session
/// endpoint and its format-compatibility check are deliberately skipped;
/// see PLAN.md Phase 5 notes).
class SteepedAudioHandler extends BaseAudioHandler with SeekHandler {
  SteepedAudioHandler() {
    _player.playbackEventStream.listen(_broadcastState);
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        // just_audio's `playing` flag only reflects explicit play()/pause()
        // calls — it never auto-flips to false on natural completion, so
        // without this the UI (Now Playing + mini-player, both driven by
        // `isPlayingProvider`) would show the pause icon forever after a
        // book finishes.
        _player.pause();
        onItemFinished?.call();
      }
    });
    // Debugging note (2026-08-03, investigating a "stuck playing" report):
    // just_audio delivers playback-time errors (dropped connection, a
    // rejected/expired stream token) via this dedicated `errorStream`, NOT
    // as a Dart Stream error on `playbackEventStream` (that pattern was
    // removed in just_audio 0.10.0 — see its changelog) — so a plain
    // `.listen(_broadcastState)` above never sees them. `_player.playing`
    // also never auto-flips to false on such an error; it only changes via
    // explicit play()/pause() calls. Without this subscription, an error
    // here is completely invisible: `_broadcastState` keeps re-emitting
    // whatever `playing`/`processingState` were before the error, forever.
    _player.errorStream.listen((e) => onPlayerError?.call(e));
  }

  /// Bug fix 2026-08-05 (evan: audible "staggering" during streamed playback,
  /// alongside a run of `receive timeout` / `Failed host lookup` progress-sync
  /// errors in Settings → Logs). Those two symptoms share one cause: a
  /// self-hosted server reached over WAN that intermittently goes slow or
  /// briefly unresolvable. `just_audio`'s defaults are tuned for short media
  /// on a good connection — 50s of buffer, and only 5s of re-buffer before
  /// resuming after an underrun — so every slow patch drains the buffer and
  /// resumes on a razor-thin margin, which is what "staggering" sounds like:
  /// repeated short stalls rather than one long one.
  ///
  /// An audiobook is low-bitrate and strictly linear, which makes a deep
  /// read-ahead almost free (2 minutes at 128kbps is under 2MB) and highly
  /// effective — it turns a 90-second server hiccup into something the
  /// listener never hears at all. [prioritizeTimeOverSizeThresholds] matters
  /// here: without it ExoPlayer stops filling once its byte target is hit,
  /// capping the read-ahead well below the durations below.
  static const _loadConfiguration = AudioLoadConfiguration(
    androidLoadControl: AndroidLoadControl(
      minBufferDuration: Duration(minutes: 2),
      maxBufferDuration: Duration(minutes: 5),
      // Left at just_audio's default: this one governs how long a *user*
      // waits after pressing play or seeking, so the Phase 5.14 loading
      // indicator shouldn't start lingering because of this fix.
      bufferForPlaybackDuration: Duration(milliseconds: 2500),
      // Deliberately much higher than the 5s default. After an underrun has
      // already happened the connection has proven itself unreliable, so
      // resuming on 5s of audio just queues up the next stall — waiting for
      // 15s trades one slightly longer pause for not stuttering repeatedly.
      bufferForPlaybackAfterRebufferDuration: Duration(seconds: 15),
      targetBufferBytes: 32 * 1024 * 1024,
      prioritizeTimeOverSizeThresholds: true,
      // Keeps recently-played audio around so the small backward jumps this
      // app encourages (the Phase 9.3 configurable back-jump, and
      // [PlaybackController]'s error recovery re-seek) usually resolve out of
      // the existing buffer instead of forcing a fresh range request to the
      // very server that was already struggling.
      backBufferDuration: Duration(seconds: 60),
    ),
    darwinLoadControl: DarwinLoadControl(
      preferredForwardBufferDuration: Duration(minutes: 5),
    ),
  );

  final AudioPlayer _player = AudioPlayer(
    audioLoadConfiguration: _loadConfiguration,
  );
  List<AudioTrack> _tracks = const [];

  /// Fired when the loaded item finishes playing entirely — used by
  /// [PlaybackController] to mark-finished / do a final progress sync.
  void Function()? onItemFinished;

  /// Fired on a `just_audio` [PlayerException] during playback (see the
  /// constructor's `errorStream` subscription above). [PlaybackController]
  /// wires this to the log repository so a silent stream failure is at
  /// least visible in Settings → Logs instead of leaving `playing: true`
  /// broadcasting forever with a frozen position.
  void Function(PlayerException)? onPlayerError;

  /// PLAN.md Phase 10.1/10.4: set once from `main.dart` after a
  /// [ProviderContainer] exists — this handler is constructed before
  /// `runApp`/`ProviderScope`, so it can't reach Riverpod providers on its
  /// own at construction time.
  CarContentTree? contentTree;

  @override
  Future<List<MediaItem>> getChildren(
    String parentMediaId, [
    Map<String, dynamic>? options,
  ]) async {
    return contentTree?.getChildren(parentMediaId) ?? const [];
  }

  @override
  Future<void> playFromMediaId(
    String mediaId, [
    Map<String, dynamic>? extras,
  ]) async {
    await contentTree?.play(mediaId);
  }

  AudioPlayer get player => _player;
  List<AudioTrack> get tracks => _tracks;

  /// [sourceUris] must be the same length/order as `item.tracks` — the
  /// caller ([PlaybackController]) decides whether those point at remote
  /// streaming URLs or downloaded local files (PLAN.md Phase 6.6); this
  /// handler doesn't know or care which.
  Future<void> loadItem({
    required LibraryItemDetail item,
    required List<Uri> sourceUris,
    double startPosition = 0,
  }) async {
    _tracks = [...item.tracks]..sort((a, b) => a.index.compareTo(b.index));
    final children = sourceUris.map(AudioSource.uri).toList();

    mediaItem.add(
      MediaItem(
        id: item.id,
        title: item.title,
        artist: item.authorNames.isEmpty ? null : item.authorNames,
        duration: item.duration == null
            ? null
            : Duration(milliseconds: (item.duration! * 1000).round()),
      ),
    );

    await _player.setAudioSources(children);
    if (startPosition > 0) {
      await seekToGlobalPosition(startPosition);
    }
  }

  /// Maps a global timeline position (what chapters are defined in terms
  /// of) onto the correct child track + offset within it.
  Future<void> seekToGlobalPosition(double seconds) async {
    if (_tracks.isEmpty) return;
    var targetIndex = _tracks.indexWhere((t) => seconds < t.endOffset);
    if (targetIndex == -1) targetIndex = _tracks.length - 1;
    final offsetWithin = (seconds - _tracks[targetIndex].startOffset).clamp(
      0,
      double.infinity,
    );
    await _player.seek(
      Duration(milliseconds: (offsetWithin * 1000).round()),
      index: targetIndex,
    );
  }

  /// Current position across the whole concatenated playlist, in seconds.
  double get globalPositionSeconds {
    if (_tracks.isEmpty) return _player.position.inMilliseconds / 1000;
    final index = _player.currentIndex ?? 0;
    final track = index < _tracks.length ? _tracks[index] : _tracks.last;
    return track.startOffset + _player.position.inMilliseconds / 1000;
  }

  Stream<double> get globalPositionStream =>
      _player.positionStream.map((_) => globalPositionSeconds);

  Future<void> jumpBy(double deltaSeconds) {
    return seekToGlobalPosition(
      (globalPositionSeconds + deltaSeconds).clamp(0, double.infinity),
    );
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Future<void> fastForward() => jumpBy(30);

  @override
  Future<void> rewind() => jumpBy(-30);

  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.rewind,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
          MediaControl.fastForward,
        ],
        systemActions: const {MediaAction.seek},
        androidCompactActionIndices: const [0, 1, 3],
        processingState:
            const {
              ProcessingState.idle: AudioProcessingState.idle,
              ProcessingState.loading: AudioProcessingState.loading,
              ProcessingState.buffering: AudioProcessingState.buffering,
              ProcessingState.ready: AudioProcessingState.ready,
              ProcessingState.completed: AudioProcessingState.completed,
            }[_player.processingState] ??
            AudioProcessingState.idle,
        playing: playing,
        updatePosition: _player.position,
        speed: _player.speed,
        queueIndex: event.currentIndex,
      ),
    );
  }
}
