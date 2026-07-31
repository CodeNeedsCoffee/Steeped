import 'package:audio_service/audio_service.dart';
import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/audio/audio_handler_provider.dart';
import 'core/audio/steeped_audio_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Activates background_downloader's persistent task database and ensures
  // proper restart after the app is suspended/killed mid-download.
  await FileDownloader().start();

  final audioHandler = await AudioService.init(
    builder: SteepedAudioHandler.new,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.steeped.steeped.audio',
      androidNotificationChannelName: 'Steeped Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );

  runApp(
    ProviderScope(
      overrides: [audioHandlerProvider.overrideWithValue(audioHandler)],
      child: const SteepedApp(),
    ),
  );
}
