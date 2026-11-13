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
import 'precise_service.dart';
import 'sync_strategy.dart';

SyncMode syncModeFromName(String name) => SyncMode.values.firstWhere(
  (m) => m.name == name,
  orElse: () => SyncMode.estimated,
);

List<ChapterSpan> audioSpansOf(LibraryItemDetail audio) => [
  for (final c in audio.chapters) ChapterSpan(c.title, c.start, c.end),
  if (audio.chapters.isEmpty && audio.duration != null)
    ChapterSpan('', 0, audio.duration!),
];

/// Where the audiobook is, to be mapped onto the ebook's chapters by the
/// reader once it has the book open (parsing the EPUB takes a moment, so the
/// switch screen change must not wait for it).
class AudioPoint {
  const AudioPoint({
    required this.seconds,
    required this.spans,
    required this.mode,
    this.audio,
  });

  /// The audiobook itself, so Precise can listen to it around [seconds].
  final LibraryItemDetail? audio;

  final double seconds;
  final List<ChapterSpan> spans;
  final SyncMode mode;

  /// The 0..1 position in a book with [ebookSpans] chapters, or null when sync
  /// is Off or nothing maps (the reader then opens at its own saved spot).
  double? fractionIn(List<ChapterSpan> ebookSpans) {
    if (mode == SyncMode.off || seconds <= 0 || spans.isEmpty) return null;
    final result = strategyFor(mode).map(seconds, spans, ebookSpans);
    return result?.position.clamp(0.0, 1.0);
  }
}

/// Where the reader is, handed over by an open reader so the switch needs no
/// network or parsing.
class EbookPoint {
  const EbookPoint({
    required this.fraction,
    required this.spans,
    this.visibleText,
  });

  /// The words at the top of the screen, for Precise to find in the audio.
  final String? visibleText;

  final double fraction;
  final List<ChapterSpan> spans;
}

/// A switch waiting for the reader to map it: ebook item id -> audio point.
final pendingEbookSwitchProvider = StateProvider<Map<String, AudioPoint>>(
  (ref) => const {},
);

/// Opens the ebook [ebook] at the spot matching where the audiobook [audio]
/// is ([audioSeconds] overrides its saved position). The screen changes at
/// once; an EPUB is mapped by the reader after it opens the book, behind its
/// own loading indicator. The reader writes the real position back on its
/// next sync.
Future<void> switchToEbook(
  BuildContext context,
  WidgetRef ref, {
  required LibraryItemDetail audio,
  required LibraryItemDetail ebook,
  double? audioSeconds,
  bool replaceCurrent = false,
}) async {
  final mode = syncModeFromName(
    ref.read(appSettingsProvider).valueOrNull?.linkSyncMode ?? 'estimated',
  );
  final seconds = audioSeconds ?? audio.progress?.currentTime ?? 0;
  final point = AudioPoint(
    seconds: seconds,
    spans: audioSpansOf(audio),
    mode: mode,
    audio: audio,
  );
  if (ebook.ebookFile?.isEpub == true) {
    if (point.fractionIn(const [ChapterSpan('', 0, 1)]) != null) {
      ref
          .read(pendingEbookSwitchProvider.notifier)
          .update((m) => {...m, ebook.id: point});
    }
  } else {
    // A PDF or comic has no chapters: map by overall fraction right now.
    final f = point.fractionIn(const [ChapterSpan('', 0, 1)]);
    if (f != null) {
      ref
          .read(pendingEbookJumpProvider.notifier)
          .update((m) => {...m, ebook.id: f});
    }
  }
  if (context.mounted) _openReader(context, ebook, replace: replaceCurrent);
}

/// Starts the audiobook [audio] at the spot matching the ebook's position.
/// Now Playing opens first (it shows a spinner until the audio is ready); the
/// position lookup and the audio load happen behind it. [from] is the open
/// reader's position, which avoids a network round trip and an EPUB parse.
Future<void> switchToAudio(
  BuildContext context,
  WidgetRef ref, {
  required LibraryItemDetail audio,
  required LibraryItemDetail ebook,
  EbookPoint? from,
  bool replaceCurrent = false,

  /// Start the audio without leaving the reader ("listen while reading").
  bool alongside = false,
}) async {
  final mode = syncModeFromName(
    ref.read(appSettingsProvider).valueOrNull?.linkSyncMode ?? 'estimated',
  );
  final router = GoRouter.of(context);
  // The widget that started this is replaced by Now Playing, which makes its
  // own `ref` unusable from here on; the app's container outlives it.
  final container = ProviderScope.containerOf(context, listen: false);
  if (!alongside) openNowPlaying(context, ref, replace: replaceCurrent);

  double? startAt;
  try {
    if (mode != SyncMode.off && audio.duration != null) {
      var fraction = from?.fraction;
      List<ChapterSpan>? spans = from?.spans;
      if (fraction == null) {
        final position = await resolveStartPosition(
          container,
          ebook.id,
          fromDetail: ebook.progress,
        );
        fraction = position?.fraction;
      }
      if (fraction != null && fraction > 0) {
        if (spans == null) {
          if (ebook.ebookFile?.isEpub == true) {
            final file = await container
                .read(ebookRepositoryProvider)
                .ensureLocalFile(ebook);
            spans = await epubChapterSpans(file);
          } else {
            spans = const [ChapterSpan('', 0, 1)];
          }
        }
        startAt = strategyFor(
          mode,
        ).map(fraction, spans, audioSpansOf(audio))?.position;
      }
    }
    // Precise: listen to the audio around the estimate and find the words
    // that are on screen. Any miss keeps the estimate.
    final words = from?.visibleText;
    if (mode == SyncMode.precise && startAt != null && words != null) {
      final refined = await refineAudioStart(container, audio, startAt, words);
      if (refined != null) startAt = refined;
    }
  } catch (_) {
    // Mapping is a convenience: fall back to the audiobook's own position.
    startAt = null;
  }

  await container
      .read(playbackControllerProvider.notifier)
      .playItem(audio.id, startAt: startAt);
  // The audio did not load (offline, no tracks): leave the spinner screen.
  if (!alongside &&
      container.read(currentPlaybackItemProvider)?.id != audio.id &&
      router.canPop()) {
    router.pop();
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
