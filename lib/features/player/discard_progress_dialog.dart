import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../library/state/library_providers.dart';
import 'state/playback_controller.dart';
import '../../l10n/l10n.dart';

/// Confirms, then forgets all listening progress for an item or episode.
/// Returns true if the progress was discarded.
Future<bool> confirmAndDiscardProgress(
  BuildContext context,
  WidgetRef ref, {
  required String libraryItemId,
  String? episodeId,
  required String title,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(context.l10n.discardProgressTitle),
      content: Text(
        context.l10n.allListeningProgressForWill(title),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(context.l10n.discard),
        ),
      ],
    ),
  );
  if (confirmed != true) return false;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref
        .read(playbackControllerProvider.notifier)
        .discardProgress(libraryItemId: libraryItemId, episodeId: episodeId);
    ref.invalidate(itemDetailProvider);
    ref.invalidate(personalizedShelvesProvider);
    messenger.showSnackBar(SnackBar(content: Text(context.l10n.progressDiscarded)));
    return true;
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text(context.l10n.couldNotDiscardProgress(e))),
    );
    return false;
  }
}
