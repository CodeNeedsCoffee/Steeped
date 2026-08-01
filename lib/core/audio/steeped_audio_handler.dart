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
        onItemFinished?.call();
      }
    });
  }

  final AudioPlayer _player = AudioPlayer();
  List<AudioTrack> _tracks = const [];

  /// Fired when the loaded item finishes playing entirely — used by
  /// [PlaybackController] to mark-finished / do a final progress sync.
  void Function()? onItemFinished;

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
