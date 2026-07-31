import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/storage/app_database.dart';
import '../data/ebook_repository.dart';
import '../data/ereader_settings.dart';

final ebookRepositoryProvider = Provider<EbookRepository>((ref) {
  return EbookRepository(ref.watch(dioProvider), ref.watch(appDatabaseProvider));
});

/// Loaded once at app scope and kept in memory; readers call
/// [EreaderSettingsController.update] to persist + broadcast a change.
class EreaderSettingsController extends AsyncNotifier<EreaderSettings> {
  @override
  Future<EreaderSettings> build() {
    return ref.read(ebookRepositoryProvider).loadSettings();
  }

  Future<void> save(EreaderSettings settings) async {
    state = AsyncData(settings);
    await ref.read(ebookRepositoryProvider).saveSettings(settings);
  }
}

final ereaderSettingsProvider =
    AsyncNotifierProvider<EreaderSettingsController, EreaderSettings>(
      EreaderSettingsController.new,
    );
