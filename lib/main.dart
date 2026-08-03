import 'package:audio_service/audio_service.dart';
import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/audio/audio_handler_provider.dart';
import 'core/audio/car_content_tree.dart';
import 'core/audio/steeped_audio_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Activates background_downloader's persistent task database and ensures
  // proper restart after the app is suspended/killed mid-download.
  await FileDownloader().start();

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

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const SteepedApp(),
    ),
  );
}
