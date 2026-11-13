import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/network/audio_stream_url.dart';
import '../../models/audio_track.dart';
import '../../models/library_item_detail.dart';
import '../auth/state/session_controller.dart';
import '../auth/state/session_state.dart';
import '../settings/state/settings_providers.dart';
import 'link_switch.dart';
import 'precise_match.dart';
import 'sync_strategy.dart';

const _channel = MethodChannel('steeped/precise');

/// True when this phone has an on-device speech recogniser (Android 13+ with
/// the speech language pack). Recognition never leaves the device.
Future<bool> preciseAvailable() async {
  try {
    final m = await _channel.invokeMapMethod<String, dynamic>('available');
    return m?['onDevice'] == true;
  } catch (_) {
    return false;
  }
}

/// Asks for the microphone permission the recogniser needs (even for a file;
/// the microphone itself is never opened). Returns whether it is granted.
Future<bool> preciseHasPermission({bool ask = false}) async {
  var status = await Permission.microphone.status;
  if (!status.isGranted && ask) status = await Permission.microphone.request();
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

/// A [Transcribe] for [audio] streaming from the signed-in server, or null when
/// Precise can't run (not selected, no permission, no recogniser, no track).
Future<Transcribe?> preciseTranscriber(
  ProviderContainer container,
  LibraryItemDetail audio,
) async {
  final mode = syncModeFromName(
    container.read(appSettingsProvider).valueOrNull?.linkSyncMode ?? '',
  );
  if (mode != SyncMode.precise) return null;
  final session = container.read(sessionControllerProvider);
  if (session is! SessionAuthenticated || audio.tracks.isEmpty) return null;
  if (!await preciseHasPermission() || !await preciseAvailable()) return null;
  return (startSec, durSec) async {
    final track = trackAt(audio.tracks, startSec);
    if (track == null) return null;
    final offset = (startSec - track.startOffset).clamp(0.0, track.duration);
    final dur = (track.duration - offset).clamp(0.0, durSec);
    if (dur < 5) return null;
    try {
      final r = await _channel.invokeMapMethod<String, dynamic>('recognize', {
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
    }
  };
}

/// Refines the Estimated audio time [estimate] using the words [visibleText]
/// that are on the reader's screen. Null keeps the estimate.
Future<double?> refineAudioStart(
  ProviderContainer container,
  LibraryItemDetail audio,
  double estimate,
  String visibleText,
) async {
  final transcribe = await preciseTranscriber(container, audio);
  if (transcribe == null) return null;
  final r = await findAudioSeconds(
    transcribe: transcribe,
    estimate: estimate,
    target: speechWords(visibleText).take(40).toList(),
    totalSeconds: audio.duration ?? double.maxFinite,
  );
  debugPrint('[precise] audio estimate=${estimate.round()}s -> ${r?.seconds.round()}s score=${r?.score.toStringAsFixed(2)}');
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
  final transcribe = await preciseTranscriber(container, audio);
  if (transcribe == null) return null;
  final r = await findParagraph(
    transcribe: transcribe,
    seconds: seconds,
    paragraphs: paragraphs,
    estimateIndex: estimateIndex,
  );
  debugPrint('[precise] paragraph estimate=$estimateIndex -> ${r?.paragraph} score=${r?.score.toStringAsFixed(2)}');
  return r == null ? null : (paragraph: r.paragraph, within: r.within);
}
