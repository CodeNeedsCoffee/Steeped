import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../player/mini_player.dart';
import '../player/state/playback_controller.dart';
import 'state/download_controller.dart';

/// PLAN.md Phase 6.5: downloads screen — in-progress + completed list,
/// delete/manage. Download queue is implicit (`background_downloader`
/// handles ordering); a dedicated "clear queue" action isn't built.
class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadsAsync = ref.watch(downloadsListProvider);
    final progress = ref.watch(downloadProgressProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Downloads')),
      body: downloadsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load: $error')),
        data: (downloads) {
          if (downloads.isEmpty) {
            return const Center(child: Text('No downloads yet.'));
          }
          return ListView.builder(
            itemCount: downloads.length,
            itemBuilder: (context, index) {
              final item = downloads[index];
              final isComplete = item.status == 'complete';
              final itemProgress = progress[item.itemId];
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
                    ? const Text('Downloaded')
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
