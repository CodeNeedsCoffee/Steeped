import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/library_item_detail.dart';
import '../ebook/state/ebook_providers.dart';
import '../player/now_playing_navigation.dart';
import '../player/state/playback_controller.dart';
import '../settings/state/settings_providers.dart';
import 'ebook_spans.dart';
import 'link_providers.dart';
import 'sync_strategy.dart';

SyncMode _modeOf(String name) => SyncMode.values.firstWhere(
  (m) => m.name == name,
  orElse: () => SyncMode.estimated,
);

/// Chapters of the ebook: an EPUB's table of contents sized by text; a PDF or
/// comic has none, so it is one span and maps by overall fraction.
Future<List<ChapterSpan>> _ebookSpans(
  WidgetRef ref,
  LibraryItemDetail ebook,
) async {
  if (ebook.ebookFile?.isEpub != true) return const [ChapterSpan('', 0, 1)];
  final file = await ref.read(ebookRepositoryProvider).ensureLocalFile(ebook);
  return epubChapterSpans(file);
}

List<ChapterSpan> _audioSpans(LibraryItemDetail audio) => [
  for (final c in audio.chapters) ChapterSpan(c.title, c.start, c.end),
];

/// Opens the ebook [ebook] at the spot matching where the audiobook [audio]
/// is ([audioSeconds] overrides its saved position). With sync Off, or when nothing maps, the reader opens at its own
/// saved position. The reader writes the real position back on its next sync.
Future<void> switchToEbook(
  BuildContext context,
  WidgetRef ref, {
  required LibraryItemDetail audio,
  required LibraryItemDetail ebook,
  double? audioSeconds,
  bool replaceCurrent = false,
}) async {
  final mode = _modeOf(
    ref.read(appSettingsProvider).valueOrNull?.linkSyncMode ?? 'estimated',
  );
  if (mode != SyncMode.off && audio.duration != null) {
    // [audioSeconds] is the live position when the audio is playing now; the
    // item's own progress is only as fresh as when its page was loaded.
    final seconds = audioSeconds ?? audio.progress?.currentTime ?? 0;
    // Only map from a spot the user has actually reached.
    if (seconds > 0) {
      final from = _audioSpans(audio).isNotEmpty
          ? _audioSpans(audio)
          : [ChapterSpan('', 0, audio.duration!)];
      final result = strategyFor(
        mode,
      ).map(seconds, from, await _ebookSpans(ref, ebook));
      if (result != null) {
        ref
            .read(pendingEbookJumpProvider.notifier)
            .update((m) => {...m, ebook.id: result.position.clamp(0.0, 1.0)});
      }
    }
  }
  if (context.mounted) _openReader(context, ebook, replace: replaceCurrent);
}

/// Starts the audiobook [audio] at the spot matching the ebook's position.
Future<void> switchToAudio(
  BuildContext context,
  WidgetRef ref, {
  required LibraryItemDetail audio,
  required LibraryItemDetail ebook,
  bool replaceCurrent = false,
}) async {
  final mode = _modeOf(
    ref.read(appSettingsProvider).valueOrNull?.linkSyncMode ?? 'estimated',
  );
  double? startAt;
  if (mode != SyncMode.off && ebook.hasEbook && audio.duration != null) {
    final position = await resolveStartPosition(
      ref,
      ebook.id,
      fromDetail: ebook.progress,
    );
    if (position != null && position.fraction > 0) {
      final to = _audioSpans(audio).isNotEmpty
          ? _audioSpans(audio)
          : [ChapterSpan('', 0, audio.duration!)];
      startAt = strategyFor(
        mode,
      ).map(position.fraction, await _ebookSpans(ref, ebook), to)?.position;
    }
  }
  await ref
      .read(playbackControllerProvider.notifier)
      .playItem(audio.id, startAt: startAt);
  if (context.mounted &&
      ref.read(currentPlaybackItemProvider)?.id == audio.id) {
    openNowPlaying(context, ref, replace: replaceCurrent);
  }
}

void _openReader(
  BuildContext context,
  LibraryItemDetail ebook, {
  bool replace = false,
}) {
  final f = ebook.ebookFile;
  if (f == null) return;
  final path = f.isEpub
      ? '/reader/epub/${ebook.id}'
      : f.isPdf
      ? '/reader/pdf/${ebook.id}'
      : '/reader/comic/${ebook.id}';
  // Replacing keeps Back going to the book page, not through every switch.
  if (replace) {
    context.pushReplacement(path);
  } else {
    context.push(path);
  }
}
