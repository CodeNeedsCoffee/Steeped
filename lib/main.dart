import 'dart:async';
import 'dart:io' show Platform;

import 'package:audio_service/audio_service.dart';
import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import 'app.dart';
import 'core/audio/audio_handler_provider.dart';
import 'core/audio/car_content_tree.dart';
import 'core/audio/steeped_audio_handler.dart';
import 'core/logging/log_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Activates background_downloader's persistent task database and ensures
  // proper restart after the app is suspended/killed mid-download.
  await FileDownloader().start();

  // Bug fix 2026-09-22 (evan: quick-settings/lock-screen media controls
  // missing entirely — confirmed live via `adb shell dumpsys
  // notification`: the app had enqueued the ongoing playback notification 6
  // times, `numPostedByApp=0`, channel `importance=NONE`, and `adb shell
  // dumpsys package` showed `POST_NOTIFICATIONS: granted=false`). Android
  // 13+ defaults this permission to denied until an app explicitly asks at
  // runtime — nothing here ever did, so the notification `audio_service`
  // depends on for its ongoing/foreground presentation was silently
  // dropped, which in turn left `MediaSessionCompat` stuck un-activated
  // (`active=false`, `state=NONE` even while genuinely playing) since
  // several `audio_service`/AndroidX Media implementations only finish
  // activating the session once the linked foreground notification actually
  // posts. Requested here, once, before the handler starts trying to post
  // that notification. Android-only: iOS's lock-screen "Now Playing"
  // widget is driven by the audio session directly and needs no
  // notification permission at all.
  if (Platform.isAndroid) {
    await Permission.notification.request();
  }

  final audioHandler = await AudioService.init(
    builder: SteepedAudioHandler.new,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.codeneedscoffee.steeped.audio',
      androidNotificationChannelName: 'Steeped Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );

  // PLAN.md Phase 10.1: a manually-created container (rather than letting
  // `ProviderScope` create one internally) so the car content tree can be
  // wired into `audioHandler` *before* `runApp` — Android Auto can call
  // `getChildren` on the handler as soon as the service exists, which may
  // be before the widget tree ever builds. `UncontrolledProviderScope`
  // hands this same container to the widget tree below, behaving
  // identically to `ProviderScope` for every existing provider.
  final container = ProviderContainer(
    overrides: [audioHandlerProvider.overrideWithValue(audioHandler)],
  );
  audioHandler.contentTree = CarContentTree(container);

  // Age out stale log entries once per launch. Not awaited: nothing in the
  // startup path reads the log, so a disk delete shouldn't sit in front of
  // the first frame.
  unawaited(container.read(logRepositoryProvider).purgeOldEntries());

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const SteepedApp(),
    ),
  );
}
