import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/network/audio_stream_url.dart';
import '../../models/audio_track.dart';
import '../../models/library_item_detail.dart';
import '../auth/state/session_controller.dart';
import '../auth/state/session_state.dart';
import '../downloads/state/download_controller.dart';
import '../settings/state/settings_providers.dart';
import 'link_switch.dart';
import 'precise_match.dart';
import 'sync_strategy.dart';

const _channel = MethodChannel('steeped/precise');

/// True when this phone has an on-device speech recogniser (Android 13+ with
/// the speech language pack, iOS 26+). Recognition never leaves the device.
Future<bool> preciseAvailable() async {
  try {
    final m = await _channel.invokeMapMethod<String, dynamic>('available');
    return m?['onDevice'] == true;
  } catch (_) {
    return false;
  }
}

/// iOS only: whether the speech language model is installed (Android has
/// nothing to install, so it is always ready).
Future<bool> preciseModelReady() async {
  if (!Platform.isIOS) return true;
  try {
    final m = await _channel.invokeMapMethod<String, dynamic>('available');
    return m?['ready'] == true;
  } catch (_) {
    return false;
  }
}

/// iOS only: installs the speech language model, reporting 0..1 as it
/// downloads. Returns whether it is ready afterwards.
Future<bool> precisePrepare({
  void Function(double fraction)? onProgress,
}) async {
  if (!Platform.isIOS) return true;
  _ensureHandler();
  _onPrepareProgress = onProgress;
  try {
    final m = await _channel.invokeMapMethod<String, dynamic>('prepare', {
      'lang': 'en-US',
    });
    return m?['ready'] == true;
  } catch (_) {
    return false;
  } finally {
    _onPrepareProgress = null;
  }
}

/// Asks for the permission the recogniser needs: the microphone on Android
/// (even for a file; the microphone itself is never opened), speech
/// recognition on iOS. Returns whether it is granted.
Future<bool> preciseHasPermission({bool ask = false}) async {
  final permission = Platform.isIOS ? Permission.speech : Permission.microphone;
  var status = await permission.status;
  if (!status.isGranted && ask) status = await permission.request();
  return status.isGranted;
}

/// The track of [tracks] holding global time [seconds].
AudioTrack? trackAt(List<AudioTrack> tracks, double seconds) {
  if (tracks.isEmpty) return null;
  var found = tracks.first;
  for (final t in tracks) {
    if (t.startOffset <= seconds) found = t;
  }
  return found;
}

/// What Precise listens with: [listen] streams the words heard so far and can
/// stop as soon as the caller is sure; [transcribe] hears a whole clip.
class PreciseListener {
  const PreciseListener(this.listen, this.transcribe);

  final Listen listen;
  final Transcribe transcribe;
}

var _nextListenId = 0;
var _activeListenId = -1;
void Function(String text, double audioSec)? _onPartial;
void Function(double fraction)? _onPrepareProgress;
var _handlerSet = false;

void _ensureHandler() {
  if (_handlerSet) return;
  _channel.setMethodCallHandler(_onChannelCall);
  _handlerSet = true;
}

// The recogniser calls back with the words so far while it works.
Future<void> _onChannelCall(MethodCall call) async {
  if (call.method == 'prepareProgress') {
    final f = (call.arguments as Map)['fraction'] as num?;
    if (f != null) _onPrepareProgress?.call(f.toDouble().clamp(0.0, 1.0));
    return;
  }
  if (call.method != 'partial') return;
  final a = call.arguments as Map;
  if (a['id'] != _activeListenId) return;
  _onPartial?.call(
    a['text'] as String? ?? '',
    ((a['audioMs'] as num?) ?? 0) / 1000,
  );
}

/// A [PreciseListener] for [audio] streaming from the signed-in server, or
/// null when Precise can't run (not selected, no permission, no recogniser,
/// no track).
Future<PreciseListener?> preciseListener(
  ProviderContainer container,
  LibraryItemDetail audio, {
  required bool toAudio,
}) async {
  final settings = container.read(appSettingsProvider).valueOrNull;
  final mode = syncModeFromName(
    (toAudio ? settings?.linkSyncToAudio : settings?.linkSyncToEbook) ?? '',
  );
  if (mode != SyncMode.precise) return null;
  final session = container.read(sessionControllerProvider);
  if (session is! SessionAuthenticated || audio.tracks.isEmpty) return null;
  if (!await preciseHasPermission() || !await preciseAvailable()) return null;
  _ensureHandler();
  // iOS listens to the downloaded files (no streaming path there yet); a
  // book that isn't fully downloaded can't use Precise.
  final local = Platform.isIOS
      ? await container
            .read(downloadRepositoryProvider)
            .buildOfflineItemDetail(audio.id)
      : null;
  if (Platform.isIOS && local == null) return null;
  Future<String?> listen(
    double startSec,
    double maxSec,
    bool Function(String text, double audioSec) enough,
  ) async {
    final track = trackAt(audio.tracks, startSec);
    if (track == null) return null;
    final offset = (startSec - track.startOffset).clamp(0.0, track.duration);
    final dur = (track.duration - offset).clamp(0.0, maxSec);
    if (dur < 5) return null;
    final localTrack = local?.tracks
        .where((t) => t.index == track.index)
        .firstOrNull;
    if (Platform.isIOS && localTrack == null) return null;
    final id = ++_nextListenId;
    _activeListenId = id;
    var stopped = false;
    var heardSec = 0.0;
    final clock = Stopwatch()..start();
    _onPartial = (text, sec) {
      if (stopped) return;
      heardSec = sec;
      if (enough(text, sec)) {
        stopped = true;
        _channel.invokeMethod<void>('cancel', {'id': id});
      }
    };
    try {
      final r = await _channel.invokeMapMethod<String, dynamic>('recognize', {
        'id': id,
        if (localTrack != null)
          'path': localTrack.contentUrl
        else
          'url': audioStreamUrl(
            serverUrl: session.serverUrl,
            relativeContentUrl: track.contentUrl,
            token: session.user.effectiveToken,
          ),
        'startMs': (offset * 1000).round(),
        'durMs': (dur * 1000).round(),
        'lang': 'en-US',
      });
      final text = r?['text'] as String?;
      // A recognition error with no words means nothing usable.
      return text == null || text.trim().isEmpty ? null : text;
    } catch (_) {
      return null;
    } finally {
      debugPrint(
        '[precise] listen at ${startSec.round()}s took ${clock.elapsedMilliseconds} ms, heard ${heardSec.toStringAsFixed(1)} s, early=$stopped',
      );
      if (_activeListenId == id) {
        _activeListenId = -1;
        _onPartial = null;
      }
    }
  }

  return PreciseListener(
    listen,
    (startSec, durSec) => listen(startSec, durSec, (_, __) => false),
  );
}

/// Refines the Estimated audio time [estimate] using the words [visibleText]
/// that are on the reader's screen. Null keeps the estimate.
Future<double?> refineAudioStart(
  ProviderContainer container,
  LibraryItemDetail audio,
  double estimate,
  String visibleText, {
  void Function(int probe, int total)? onProbe,
  ({List<String> paragraphs, double position})? guide,
}) async {
  final listener = await preciseListener(container, audio, toAudio: true);
  if (listener == null) return null;
  final target = speechWords(visibleText).take(40).toList();
  final total = audio.duration ?? double.maxFinite;
  final r = guide != null
      ? await findAudioSecondsGuided(
          transcribe: listener.transcribe,
          listen: listener.listen,
          estimate: estimate,
          paragraphs: guide.paragraphs,
          position: guide.position,
          target: target,
          totalSeconds: total,
          onStep: onProbe,
        )
      : await findAudioSeconds(
          transcribe: listener.transcribe,
          estimate: estimate,
          target: speechWords(visibleText).take(40).toList(),
          totalSeconds: audio.duration ?? double.maxFinite,
          onProbe: onProbe,
        );
  debugPrint(
    '[precise] audio estimate=${estimate.round()}s -> ${r?.seconds.round()}s score=${r?.score.toStringAsFixed(2)} readerAt=${guide?.position.toStringAsFixed(2)}',
  );
  return r?.seconds;
}

/// Refines the Estimated reader position for the audiobook at [seconds] to the
/// paragraph the narrator is actually reading. Null keeps the estimate.
Future<({int paragraph, double within})?> refineParagraph(
  ProviderContainer container,
  LibraryItemDetail audio,
  double seconds,
  List<String> paragraphs,
  int estimateIndex,
) async {
  final listener = await preciseListener(container, audio, toAudio: false);
  if (listener == null) return null;
  final r = await findParagraph(
    listen: listener.listen,
    seconds: seconds,
    paragraphs: paragraphs,
    estimateIndex: estimateIndex,
  );
  debugPrint(
    '[precise] paragraph estimate=$estimateIndex -> ${r?.paragraph} score=${r?.score.toStringAsFixed(2)} heard=${r?.heardSeconds.toStringAsFixed(1)}s',
  );
  return r == null ? null : (paragraph: r.paragraph, within: r.within);
}
