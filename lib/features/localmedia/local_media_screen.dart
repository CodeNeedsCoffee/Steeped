import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../player/mini_player.dart';
import '../player/state/playback_controller.dart';
import 'state/local_media_providers.dart';

/// PLAN.md Phase 6.8: on-device audio import/scan, with no server involved
/// — simplified to single-file import (see `LocalMediaRepository`'s doc
/// comment for why a full folder scan was skipped). A genuinely separate
/// list from the Downloads screen since these items have no server item id.
class LocalMediaScreen extends ConsumerWidget {
  const LocalMediaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(localMediaListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Local Media'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Import a file',
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final title = await ref
                  .read(localMediaRepositoryProvider)
                  .importFile();
              if (title != null) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Imported "$title"')),
                );
              }
            },
          ),
        ],
      ),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load: $error')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No local media yet. Tap + to import an audio file from '
                  'this device — these never touch the server.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final progress = item.progressCurrentTime;
              final duration = item.durationSeconds;
              final subtitle = duration == null
                  ? null
                  : progress != null && duration > 0
                  ? '${(progress / duration * 100).clamp(0, 100).round()}% '
                        'played · ${_formatDuration(duration)}'
                  : _formatDuration(duration);
              return ListTile(
                leading: const Icon(Icons.music_note_outlined),
                title: Text(item.title),
                subtitle: subtitle == null ? null : Text(subtitle),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => ref
                      .read(localMediaRepositoryProvider)
                      .delete(item.id),
                ),
                onTap: () async {
                  await ref
                      .read(playbackControllerProvider.notifier)
                      .playLocalMedia(item.id);
                  if (context.mounted) context.push('/now-playing');
                },
              );
            },
          );
        },
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }

  String _formatDuration(double seconds) {
    final totalMinutes = (seconds / 60).round();
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours == 0) return '${minutes}m';
    return '${hours}h ${minutes}m';
  }
}
