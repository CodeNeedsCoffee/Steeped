import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/library_item_detail.dart';

import '../../l10n/l10n.dart';
import '../library/state/library_providers.dart';
import 'link_providers.dart';
import 'link_switch.dart';
import 'read_along.dart';
import 'switch_menu.dart';

/// A headphones button for a reader's app bar: when this ebook is linked to an
/// audiobook, saves the reading position ([saveFirst]) and starts the audio at
/// the matching spot. Shows nothing when the book has no linked audiobook.
class LinkedListenAction extends ConsumerWidget {
  const LinkedListenAction({
    required this.itemId,
    required this.saveFirst,
    this.pointNow,
    this.onListenAlongside,
    this.canListenAlongside = false,
    super.key,
  });

  final String itemId;
  final VoidCallback saveFirst;

  /// The reader's current position, so the switch needs no network or EPUB
  /// parse. Null falls back to looking it up.
  final EbookPoint Function()? pointNow;

  /// Called after audio was started beside the reader (so it can start
  /// following it) or when "Show player" was chosen.
  final VoidCallback? onListenAlongside;

  /// Only the EPUB reader has a player strip and a page to follow; a PDF or
  /// comic just switches.
  final bool canListenAlongside;

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
    final playing = ref.watch(linkedPlayingProvider(itemId)) != null;
    // A Builder so the menu drops from the button itself.
    return Builder(
      builder: (buttonContext) => GestureDetector(
        onLongPress: audio == null || ebook == null
            ? null
            : () => _go(buttonContext, ref, audio, ebook, playing, true),
        child: IconButton(
          icon: const Icon(Icons.headphones),
          tooltip: context.l10n.listenLinked,
          onPressed: audio == null || ebook == null
              ? null
              : () => _go(buttonContext, ref, audio, ebook, playing, false),
        ),
      ),
    );
  }

  Future<void> _go(
    BuildContext context,
    WidgetRef ref,
    LibraryItemDetail audio,
    LibraryItemDetail ebook,
    bool playing,
    bool forceAsk,
  ) async {
    final l10n = context.l10n;
    final choice = !canListenAlongside
        ? SwitchChoice.switchOnly
        : await chooseSwitch(
            context,
            ref,
            switchLabel: l10n.switchToAudiobook,
            bothLabel: l10n.listenWhileReading,
            showPlayerLabel: l10n.showPlayer,
            alreadyPlaying: playing,
            forceAsk: forceAsk,
          );
    if (choice == null || !context.mounted) return;
    saveFirst();
    switch (choice) {
      case SwitchChoice.switchOnly:
        // Replace the reader so Back returns to the book page.
        await switchToAudio(
          context,
          ref,
          audio: audio,
          ebook: ebook,
          from: pointNow?.call(),
          replaceCurrent: true,
        );
      case SwitchChoice.both:
        await switchToAudio(
          context,
          ref,
          audio: audio,
          ebook: ebook,
          from: pointNow?.call(),
          alongside: true,
        );
        onListenAlongside?.call();
      case SwitchChoice.showPlayer:
        onListenAlongside?.call();
    }
  }
}
