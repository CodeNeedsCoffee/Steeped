import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'steeped_audio_handler.dart';

/// audio_service requires its handler to be created once, at startup,
/// before `runApp` — so this is overridden with the real instance in
/// `main.dart` rather than constructed lazily like other providers.
final audioHandlerProvider = Provider<SteepedAudioHandler>((ref) {
  throw UnimplementedError(
    'audioHandlerProvider must be overridden in main.dart',
  );
});
