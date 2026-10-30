import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/playback_loading_badge.dart';
import '../player/mini_player.dart';
import '../player/now_playing_navigation.dart';
import '../player/state/playback_controller.dart';
import 'state/local_media_providers.dart';
import '../../l10n/l10n.dart';
import '../../core/utils/format_duration.dart';

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
        title: Text(context.l10n.localMedia),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: context.l10n.importAFile,
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final title = await ref
                  .read(localMediaRepositoryProvider)
                  .importFile();
              if (title != null) {
                messenger.showSnackBar(
                  SnackBar(content: Text(context.l10n.imported(title))),
                );
              }
            },
          ),
        ],
      ),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(context.l10n.failedToLoad(error))),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  context.l10n.noLocalMediaYetTap,
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
                  ? context.l10n.percentPlayedDuration(
                      (progress / duration * 100).clamp(0, 100).round(),
                      formatDurationText(context.l10n, duration),
                    )
                  : formatDurationText(context.l10n, duration);
              final isLoading =
                  ref.watch(playbackLoadingIdProvider) == item.id;
              return ListTile(
                enabled: !isLoading,
                leading: PlaybackLoadingBadge(
                  isLoading: isLoading,
                  child: const Icon(Icons.music_note_outlined),
                ),
                title: Text(item.title),
                subtitle: subtitle == null ? null : Text(subtitle),
                trailing: IconButton(
                  tooltip: context.l10n.delete,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => ref
                      .read(localMediaRepositoryProvider)
                      .delete(item.id),
                ),
                onTap: () async {
                  await ref
                      .read(playbackControllerProvider.notifier)
                      .playLocalMedia(item.id);
                  if (context.mounted &&
                      ref.read(currentPlaybackItemProvider)?.id == item.id) {
                    openNowPlaying(context, ref);
                  }
                },
              );
            },
          );
        },
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }

}
