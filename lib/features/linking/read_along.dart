import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/library_item_detail.dart';
import '../library/state/library_providers.dart';
import '../player/state/playback_controller.dart';
import 'link_providers.dart';
import 'link_switch.dart';
import 'sync_strategy.dart';

/// The audiobook linked to the ebook [ebookId], once its details are loaded;
/// null for an unlinked book.
final linkedAudioProvider = Provider.autoDispose
    .family<LibraryItemDetail?, String>((ref, ebookId) {
      final link = ref.watch(itemLinkProvider(ebookId)).valueOrNull;
      if (link == null || link.ebookItemId != ebookId) return null;
      return ref.watch(itemDetailProvider(link.audioItemId)).valueOrNull;
    });

/// The linked audiobook of [ebookId] while it is the one loaded in the player.
/// This is what decides whether the reader shows its player strip: nothing
/// else that happens to be playing gets one.
final linkedPlayingProvider = Provider.autoDispose
    .family<LibraryItemDetail?, String>((ref, ebookId) {
      final audio = ref.watch(linkedAudioProvider(ebookId));
      final current = ref.watch(currentPlaybackItemProvider);
      return audio != null && current?.id == audio.id ? audio : null;
    });

/// Now Playing's read-along text window is open (set by "Read along").
final readAlongOpenProvider = StateProvider<bool>((ref) => false);

/// The paragraph position (paragraph index plus how far into it) the audio
/// is at, or null when sync is Off or nothing maps.
double? followPosition(
  AudioPoint point,
  List<ChapterSpan> ebookSpans,
  int paragraphCount,
) {
  final f = point.fractionIn(ebookSpans);
  if (f == null || paragraphCount <= 0) return null;
  return (f * paragraphCount).clamp(0.0, paragraphCount - 0.0001);
}

/// The audio time for the start of paragraph [index] (play from here).
double? audioSecondsForParagraph({
  required int index,
  required int paragraphCount,
  required List<ChapterSpan> ebookSpans,
  required List<ChapterSpan> audioSpans,
  required SyncMode mode,
}) {
  if (mode == SyncMode.off || paragraphCount <= 0) return null;
  final fraction = (index / paragraphCount).clamp(0.0, 1.0);
  return strategyFor(mode).map(fraction, ebookSpans, audioSpans)?.position;
}

/// True when the audio's paragraph is already comfortably on screen, so
/// following only moves the marker instead of scrolling the page.
bool inComfortZone({
  required double paragraphTop,
  required double bodyTop,
  required double bodyHeight,
}) =>
    paragraphTop >= bodyTop + bodyHeight * 0.05 &&
    paragraphTop <= bodyTop + bodyHeight * 0.8;

/// The chapter holding [seconds]: its title, how many seconds remain in it,
/// and its start/end. Null when there are no chapters.
({String title, double left, double start, double end})? chapterProgressAt(
  List<ChapterSpan> chapters,
  double seconds,
) {
  if (chapters.isEmpty) return null;
  var c = chapters.last;
  for (final x in chapters) {
    if (seconds < x.end) {
      c = x;
      break;
    }
  }
  return (
    title: c.title,
    left: (c.end - seconds).clamp(0.0, double.infinity),
    start: c.start,
    end: c.end,
  );
}
