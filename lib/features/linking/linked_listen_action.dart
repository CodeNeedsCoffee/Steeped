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
    this.pointNow,
    super.key,
  });

  final String itemId;
  final VoidCallback saveFirst;

  /// The reader's current position, so the switch needs no network or EPUB
  /// parse. Null falls back to looking it up.
  final EbookPoint Function()? pointNow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final link = ref.watch(itemLinkProvider(itemId)).valueOrNull;
    if (link == null || link.ebookItemId != itemId) {
      return const SizedBox.shrink();
    }
    // Watched so both are loaded before the button is pressed (they are
    // auto-disposing, so reading them on tap could mean a network wait).
    final audio = ref.watch(itemDetailProvider(link.audioItemId)).valueOrNull;
    final ebook = ref.watch(itemDetailProvider(itemId)).valueOrNull;
    return IconButton(
      icon: const Icon(Icons.headphones),
      tooltip: context.l10n.listenLinked,
      onPressed: audio == null || ebook == null
          ? null
          : () {
              saveFirst();
              // Replace the reader so Back returns to the book page.
              switchToAudio(
                context,
                ref,
                audio: audio,
                ebook: ebook,
                from: pointNow?.call(),
                replaceCurrent: true,
              );
            },
    );
  }
}
