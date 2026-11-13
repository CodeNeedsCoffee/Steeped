import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../models/library_item_detail.dart';
import '../library/state/library_providers.dart';
import '../player/state/playback_controller.dart';
import 'link_providers.dart';
import 'link_switch.dart';

/// A book icon for Now Playing: when the audiobook being played is linked to an
/// ebook, opens the ebook at the spot matching the live playback position.
/// Shows nothing when there is no link.
class LinkedReadAction extends ConsumerWidget {
  const LinkedReadAction({required this.audio, super.key});

  final LibraryItemDetail audio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (audio.isLocalOnly || audio.isEpisode) return const SizedBox.shrink();
    final link = ref.watch(itemLinkProvider(audio.id)).valueOrNull;
    if (link == null || link.audioItemId != audio.id) {
      return const SizedBox.shrink();
    }
    // Watched so the ebook is loaded before the button is pressed.
    final ebook = ref.watch(itemDetailProvider(link.ebookItemId)).valueOrNull;
    return IconButton(
      icon: const Icon(Icons.menu_book_outlined),
      tooltip: context.l10n.readLinked,
      onPressed: ebook == null
          ? null
          : () => switchToEbook(
              context,
              ref,
              audio: audio,
              ebook: ebook,
              audioSeconds: ref.read(playbackPositionProvider).valueOrNull,
              replaceCurrent: true,
            ),
    );
  }
}
