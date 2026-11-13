import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/storage/app_database.dart';
import '../../auth/state/session_controller.dart' show activeProfileIdProvider;
import '../data/ebook_repository.dart';
import '../data/pending_ebook_progress_store.dart';
import '../../../models/media_progress.dart';
import '../../player/state/playback_controller.dart' show progressRepositoryProvider;
import '../data/ereader_settings.dart';
import '../data/reading_position.dart';

final pendingEbookProgressStoreProvider = Provider<PendingEbookProgressStore>(
  (ref) => PendingEbookProgressStore(
    ref.watch(appDatabaseProvider),
    profileId: ref.watch(activeProfileIdProvider) ?? '',
  ),
);

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

/// Picks where to open a book: the newer of the server's position (fetched
/// fresh, since the item-detail copy can be stale) and the one saved on this
/// device. A failed or offline server lookup falls back to the local copy and
/// then to whatever the item-detail response carried.
Future<ReadingPosition?> resolveStartPosition(
  ProviderContainer container,
  String itemId, {
  MediaProgress? fromDetail,
}) async {
  final repo = container.read(ebookRepositoryProvider);
  final local = await repo.loadPosition(itemId);
  MediaProgress? server = fromDetail;
  try {
    server = await container.read(progressRepositoryProvider).fetchProgress(itemId);
  } catch (_) {
    // Offline: keep the detail copy.
  }
  final serverPos = (server?.ebookLocation?.isNotEmpty ?? false)
      ? ReadingPosition(
          location: server!.ebookLocation!,
          fraction: server.ebookProgress ?? 0,
          updatedAt: server.lastUpdate ?? DateTime.fromMillisecondsSinceEpoch(0),
        )
      : null;
  if (serverPos == null) return local;
  if (local == null) return serverPos;
  return local.updatedAt.isAfter(serverPos.updatedAt) ? local : serverPos;
}

/// Whether a reader should send `isFinished: true`. An item that also has
/// audio shares one progress row between the audiobook and the ebook, so
/// reaching the end of the ebook must not mark the audiobook finished.
/// Returns null (leave the server flag alone) rather than false.
bool? ebookFinishedFlag({required bool reachedEnd, required bool hasAudio}) =>
    reachedEnd && !hasAudio ? true : null;

/// Writes the position to the device first (so it survives going offline or a
/// crash), then to the server. A server failure is swallowed: the local copy
/// wins on the next open until the server catches up.
Future<void> saveReadingPosition(
  WidgetRef ref, {
  required String itemId,
  required String location,
  required double fraction,
  bool? isFinished,
}) async {
  final f = fraction.clamp(0.0, 1.0);
  await ref
      .read(ebookRepositoryProvider)
      .savePosition(
        itemId,
        ReadingPosition(
          location: location,
          fraction: f,
          updatedAt: DateTime.now(),
        ),
      );
  final queue = ref.read(pendingEbookProgressStoreProvider);
  final at = DateTime.now();
  try {
    await ref
        .read(progressRepositoryProvider)
        .updateEbookProgress(
          libraryItemId: itemId,
          ebookLocation: location,
          ebookProgress: f,
          isFinished: isFinished,
        );
    await queue.remove(itemId, sentAt: at);
  } catch (e) {
    // Keep it for the sync controller, which retries on reconnect, on app
    // start and every few minutes (a failed upload used to be retried only
    // on the next page turn).
    debugPrint('[ebook-sync] PATCH failed for $itemId, queued: $e');
    await queue.put(
      PendingEbookProgress(
        itemId: itemId,
        location: location,
        fraction: f,
        at: at,
        isFinished: isFinished,
      ),
    );
  }
}
