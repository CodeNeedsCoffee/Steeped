import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/cover_image_url.dart';
import '../../widgets/cover_image.dart';
import '../auth/state/session_controller.dart';
import '../auth/state/session_state.dart';
import 'state/playback_controller.dart';

/// PLAN.md Phase 5.2: persistent bottom bar. Drop this in as a Scaffold's
/// `bottomNavigationBar` on any authenticated screen — it collapses to
/// nothing when no item is loaded.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(currentPlaybackItemProvider);
    if (item == null) return const SizedBox.shrink();

    final session = ref.watch(sessionControllerProvider);
    final isPlaying = ref.watch(isPlayingProvider).valueOrNull ?? false;
    final (serverUrl, token) = switch (session) {
      SessionAuthenticated(:final serverUrl, :final user) => (
        serverUrl,
        user.effectiveToken,
      ),
      _ => (null, null),
    };

    return SafeArea(
      top: false,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        child: InkWell(
          onTap: () => context.push('/now-playing'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                if (serverUrl != null)
                  CoverImage(
                    url: coverImageUrl(
                      serverUrl: serverUrl,
                      itemId: item.id,
                      token: token,
                      updatedAt: item.updatedAt,
                    ),
                    width: 40,
                    height: 40,
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                IconButton(
                  icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                  onPressed: () {
                    final controller = ref.read(
                      playbackControllerProvider.notifier,
                    );
                    isPlaying ? controller.pause() : controller.resume();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
