import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/cover_image_url.dart';
import '../../core/theme/app_skin_style.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/cover_image.dart';
import '../../widgets/glass_surface.dart';
import '../../widgets/playback_loading_badge.dart';
import '../auth/state/session_controller.dart';
import '../auth/state/session_state.dart';
import '../settings/state/settings_providers.dart';
import 'state/playback_controller.dart';

/// PLAN.md Phase 5.2: persistent bottom bar. Drop this in as a Scaffold's
/// `bottomNavigationBar` on any authenticated screen — it collapses to
/// nothing when no item is loaded.
///
/// PLAN.md Phase 5.15/5.16/5.17: a floating, elevated card rather than a
/// flat edge-to-edge bar — skin-aware (frosted via [GlassSurface] on Glass
/// Modern, opaque on Bookshelf, matching how every other surface already
/// diverges per skin), with an expand chevron next to the cover and its own
/// 30s jump controls (all sized up per evan's follow-up feedback) so the two
/// most common actions don't require opening Now Playing first.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Centralized here (PLAN.md Phase 9.3) rather than at every play/download
    // call site, since MiniPlayer is already mounted on nearly every
    // authenticated screen.
    ref.listen(cellularBlockNoticeProvider, (previous, next) {
      if (next == null) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next)));
      Future.microtask(
        () => ref.read(cellularBlockNoticeProvider.notifier).state = null,
      );
    });

    final item = ref.watch(currentPlaybackItemProvider);
    if (item == null) return const SizedBox.shrink();

    final session = ref.watch(sessionControllerProvider);
    final isPlaying = ref.watch(isPlayingProvider).valueOrNull ?? false;
    // PLAN.md Phase 5.14 reuse: the mini-player's own play/pause button sits
    // outside that phase's original sweep (which only covered rows that
    // *start* a load elsewhere) — but resuming/switching items from the
    // collapsed bar goes through the same [playbackLoadingIdProvider], so it
    // gets the identical spinner treatment instead of looking unresponsive
    // during the fetch-then-buffer gap.
    final isLoading = ref.watch(playbackLoadingIdProvider) == item.downloadId;
    final controller = ref.read(playbackControllerProvider.notifier);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final radii = theme.extension<AppRadii>() ?? const AppRadii();
    final isFrosted =
        theme.extension<AppSkinStyle>()?.useFrostedSurfaces ?? false;
    final (serverUrl, token) = switch (session) {
      SessionAuthenticated(:final serverUrl, :final user) => (
        serverUrl,
        user.effectiveToken,
      ),
      _ => (null, null),
    };

    final content = InkWell(
      onTap: () => context.push('/now-playing'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_up),
              iconSize: 36,
              tooltip: 'Expand',
              onPressed: () => context.push('/now-playing'),
            ),
            if (serverUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(radii.sm),
                child: CoverImage(
                  url: coverImageUrl(
                    serverUrl: serverUrl,
                    itemId: item.id,
                    token: token,
                    updatedAt: item.updatedAt,
                  ),
                  width: 40,
                  height: 40,
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.replay_30),
              iconSize: 28,
              visualDensity: VisualDensity.compact,
              tooltip: 'Back 30 seconds',
              onPressed: controller.jumpBackward,
            ),
            PlaybackLoadingBadge(
              isLoading: isLoading,
              child: IconButton(
                icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                iconSize: 36,
                onPressed: isLoading
                    ? null
                    : () => isPlaying ? controller.pause() : controller.resume(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.forward_30),
              iconSize: 28,
              visualDensity: VisualDensity.compact,
              tooltip: 'Forward 30 seconds',
              onPressed: controller.jumpForward,
            ),
          ],
        ),
      ),
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Material(
          color: Colors.transparent,
          elevation: 8,
          shadowColor: Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(radii.lg),
          clipBehavior: Clip.antiAlias,
          child: isFrosted
              ? GlassSurface(child: content)
              : Container(color: scheme.surfaceContainerHigh, child: content),
        ),
      ),
    );
  }
}
