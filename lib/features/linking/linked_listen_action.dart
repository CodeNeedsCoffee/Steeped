import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../library/state/library_providers.dart';
import 'link_providers.dart';
import 'link_switch.dart';

/// A headphones button for a reader's app bar: when this ebook is linked to an
/// audiobook, saves the reading position ([saveFirst]) and starts the audio at
/// the matching spot. Shows nothing when the book has no linked audiobook.
class LinkedListenAction extends ConsumerWidget {
  const LinkedListenAction({
    required this.itemId,
    required this.saveFirst,
    super.key,
  });

  final String itemId;
  final VoidCallback saveFirst;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final link = ref.watch(itemLinkProvider(itemId)).valueOrNull;
    if (link == null || link.ebookItemId != itemId) {
      return const SizedBox.shrink();
    }
    return IconButton(
      icon: const Icon(Icons.headphones),
      tooltip: context.l10n.listenLinked,
      onPressed: () async {
        saveFirst();
        final audio = await ref.read(itemDetailProvider(link.audioItemId).future);
        final ebook = await ref.read(itemDetailProvider(itemId).future);
        if (!context.mounted) return;
        // Replace the reader so Back returns to the book page, not the reader.
        await switchToAudio(
          context,
          ref,
          audio: audio,
          ebook: ebook,
          replaceCurrent: true,
        );
      },
    );
  }
}
