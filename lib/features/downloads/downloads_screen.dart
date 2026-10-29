import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/format_bytes.dart';
import '../../widgets/playback_loading_badge.dart';
import '../player/mini_player.dart';
import '../player/now_playing_navigation.dart';
import '../player/state/playback_controller.dart';
import '../../core/network/connectivity_service.dart';
import '../auth/data/server_profile_repository.dart';
import '../auth/state/profile_switcher.dart' show hostOfServerUrl;
import '../auth/state/session_controller.dart';
import '../settings/data/app_settings.dart';
import '../settings/state/settings_providers.dart';
import '../../core/storage/app_database.dart' show DownloadedItem;
import 'download_groups.dart';
import 'state/download_controller.dart';
import '../../l10n/l10n.dart';

/// PLAN.md Phase 6.5: downloads screen — in-progress + completed list,
/// delete/manage. Download queue is implicit (`background_downloader`
/// handles ordering); a dedicated "clear queue" action isn't built.
///
/// PLAN.md Phase 6.10: also carries storage management — total space used,
/// a low-storage warning against real free device space, and bulk-delete.
class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  Future<void> _confirmDeleteAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.deleteAllDownloadsTitle),
        content: Text(
          context.l10n.thisRemovesEveryDownloadedBook,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.deleteAll),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(downloadControllerProvider.notifier).deleteAll();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadsAsync = ref.watch(downloadsListProvider);
    final progress = ref.watch(downloadProgressProvider);
    final totalSizeAsync = ref.watch(downloadsTotalSizeProvider);
    final freeSpaceAsync = ref.watch(deviceFreeSpaceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.downloads),
        actions: [
          downloadsAsync.maybeWhen(
            data: (downloads) => downloads.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    icon: const Icon(Icons.delete_sweep_outlined),
                    tooltip: context.l10n.deleteAllDownloadsTooltip,
                    onPressed: () => _confirmDeleteAll(context, ref),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: downloadsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(context.l10n.failedToLoad(error))),
        data: (downloads) {
          if (downloads.isEmpty) {
            return Center(child: Text(context.l10n.noDownloadsYet));
          }
          final freeBytes = freeSpaceAsync.valueOrNull;
          final isLowStorage =
              freeBytes != null && freeBytes < lowStorageThresholdBytes;
          final settings = ref.watch(appSettingsProvider).valueOrNull ??
              const AppSettings();
          final offline =
              ref.watch(networkKindProvider).valueOrNull == NetworkKind.none;
          final profiles =
              ref.watch(serverProfilesProvider).valueOrNull ?? const [];
          final groups = groupDownloads(
            downloads,
            activeProfileId: ref.watch(activeProfileIdProvider),
            offline: offline,
            showOtherServers: settings.showOtherServerDownloads,
          );
          final showHeaders = groups.length > 1 || groups.any((g) => !g.isActive);

          // Flat list: summary, then per group an optional header + its items.
          final rows = <Object>[
            const _SummaryRow(),
            for (final g in groups) ...[
              if (showHeaders) g,
              ...g.items,
            ],
          ];
          if (rows.length == 1) {
            return Center(child: Text(context.l10n.noDownloadsYet));
          }
          return ListView.builder(
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final row = rows[index];
              if (row is _SummaryRow) {
                return _StorageSummary(
                  totalUsed: totalSizeAsync.valueOrNull,
                  freeBytes: freeBytes,
                  isLowStorage: isLowStorage,
                );
              }
              if (row is DownloadGroup) {
                final profile = profiles
                    .where((p) => p.id == row.profileId)
                    .firstOrNull;
                final host = hostOfServerUrl(row.serverUrl);
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                  child: Text(
                    row.isActive
                        ? context.l10n.downloadsFromServer(host)
                        : profile != null
                        ? context.l10n.accountOnServer(profile.username, host)
                        : context.l10n.downloadsFromServer(host),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                );
              }
              final item = row as DownloadedItem;
              final isComplete = item.status == 'complete';
              final itemProgress = progress[item.itemId];
              final sizeAsync = ref.watch(
                downloadItemSizeProvider(item.itemId),
              );
              final isLoading =
                  ref.watch(playbackLoadingIdProvider) == item.itemId;
              return ListTile(
                enabled: !isLoading,
                leading: PlaybackLoadingBadge(
                  isLoading: isLoading,
                  child: DownloadedItemCover(
                    coverLocalPath: item.coverLocalPath,
                  ),
                ),
                title: Text(item.title),
                subtitle: isComplete
                    ? Text(
                        sizeAsync.maybeWhen(
                          data: (bytes) =>
                              context.l10n.downloadedWithSize(formatBytes(bytes)),
                          orElse: () => context.l10n.downloaded,
                        ),
                      )
                    : LinearProgressIndicator(value: itemProgress),
                trailing: IconButton(
                  tooltip: context.l10n.deleteDownload,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => ref
                      .read(downloadControllerProvider.notifier)
                      .delete(item.itemId),
                ),
                onTap: isComplete && !isLoading
                    ? () async {
                        await ref
                            .read(playbackControllerProvider.notifier)
                            .playItem(item.itemId);
                        if (context.mounted &&
                            ref.read(currentPlaybackItemProvider)?.downloadId ==
                                item.itemId) {
                          openNowPlaying(context, ref);
                        }
                      }
                    : null,
              );
            },
          );
        },
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}

/// Cover art for a downloaded item — a local file, not a server URL, so it
/// deliberately bypasses [CoverImage]/[CachedNetworkImage] (which would need
/// a network round trip the offline paths can't make). Shared with the
/// offline Home tab in [HomeShellScreen].
class DownloadedItemCover extends StatelessWidget {
  const DownloadedItemCover({required this.coverLocalPath, super.key});

  final String? coverLocalPath;

  @override
  Widget build(BuildContext context) {
    final path = coverLocalPath;
    if (path == null) return const Icon(Icons.menu_book_outlined);
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.file(
        File(path),
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) =>
            const Icon(Icons.menu_book_outlined),
      ),
    );
  }
}

class _SummaryRow {
  const _SummaryRow();
}

class _StorageSummary extends StatelessWidget {
  const _StorageSummary({
    required this.totalUsed,
    required this.freeBytes,
    required this.isLowStorage,
  });

  final int? totalUsed;
  final int? freeBytes;
  final bool isLowStorage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            totalUsed == null
                ? context.l10n.calculatingStorage
                : freeBytes != null
                ? context.l10n.downloadsUseWithFree(
                    formatBytes(totalUsed!),
                    formatBytes(freeBytes!),
                  )
                : context.l10n.downloadsUse(formatBytes(totalUsed!)),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (isLowStorage) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.l10n.storageIsRunningLowDelete,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Divider(height: 24),
        ],
      ),
    );
  }
}
