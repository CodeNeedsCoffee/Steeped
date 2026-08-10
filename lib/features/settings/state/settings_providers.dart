import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/app_database.dart';
import '../data/app_settings.dart';
import '../data/app_settings_repository.dart';

final appSettingsRepositoryProvider = Provider<AppSettingsRepository>((ref) {
  return AppSettingsRepository(ref.watch(appDatabaseProvider));
});

class AppSettingsController extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() {
    return ref.read(appSettingsRepositoryProvider).load();
  }

  Future<void> save(AppSettings settings) async {
    state = AsyncData(settings);
    await ref.read(appSettingsRepositoryProvider).save(settings);
  }
}

final appSettingsProvider =
    AsyncNotifierProvider<AppSettingsController, AppSettings>(
      AppSettingsController.new,
    );

/// Set by [PlaybackController]/[DownloadController] when a cellular data
/// setting blocks an action; [MiniPlayer] (present on nearly every
/// authenticated screen) watches this and surfaces a snackbar, so the
/// dozen+ places a play/download can be triggered from don't each need
/// their own error-handling wiring.
final cellularBlockNoticeProvider = StateProvider<String?>((ref) => null);
