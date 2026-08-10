import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/format_bytes.dart';
import '../player/mini_player.dart';
import '../player/state/playback_controller.dart';
import 'state/download_controller.dart';

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
        title: const Text('Delete all downloads?'),
        content: const Text(
          'This removes every downloaded book and episode from this device. '
          'They remain on the server and can be downloaded again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete All'),
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
        title: const Text('Downloads'),
        actions: [
          downloadsAsync.maybeWhen(
            data: (downloads) => downloads.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    icon: const Icon(Icons.delete_sweep_outlined),
                    tooltip: 'Delete all downloads',
                    onPressed: () => _confirmDeleteAll(context, ref),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: downloadsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load: $error')),
        data: (downloads) {
          if (downloads.isEmpty) {
            return const Center(child: Text('No downloads yet.'));
          }
          final freeBytes = freeSpaceAsync.valueOrNull;
          final isLowStorage =
              freeBytes != null && freeBytes < lowStorageThresholdBytes;
          return ListView.builder(
            itemCount: downloads.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _StorageSummary(
                  totalUsed: totalSizeAsync.valueOrNull,
                  freeBytes: freeBytes,
                  isLowStorage: isLowStorage,
                );
              }
              final item = downloads[index - 1];
              final isComplete = item.status == 'complete';
              final itemProgress = progress[item.itemId];
              final sizeAsync = ref.watch(
                downloadItemSizeProvider(item.itemId),
              );
              return ListTile(
                leading: item.coverLocalPath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.file(
                          File(item.coverLocalPath!),
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) =>
                              const Icon(Icons.menu_book_outlined),
                        ),
                      )
                    : const Icon(Icons.menu_book_outlined),
                title: Text(item.title),
                subtitle: isComplete
                    ? Text(
                        sizeAsync.maybeWhen(
                          data: (bytes) => 'Downloaded · ${formatBytes(bytes)}',
                          orElse: () => 'Downloaded',
                        ),
                      )
                    : LinearProgressIndicator(value: itemProgress),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => ref
                      .read(downloadControllerProvider.notifier)
                      .delete(item.itemId),
                ),
                onTap: isComplete
                    ? () async {
                        await ref
                            .read(playbackControllerProvider.notifier)
                            .playItem(item.itemId);
                        if (context.mounted) context.push('/now-playing');
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
                ? 'Calculating storage used…'
                : 'Downloads use ${formatBytes(totalUsed!)}'
                      '${freeBytes != null ? ' · ${formatBytes(freeBytes!)} free' : ''}',
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
                      'Storage is running low. Delete a download to free '
                      'up space.',
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
