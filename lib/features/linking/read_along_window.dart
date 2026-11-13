import 'package:epub_view/epub_view.dart' show EpubBook;
// ignore: implementation_imports
import 'package:epub_view/src/data/epub_parser.dart' show parseChapters, parseParagraphs;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/library_item_detail.dart';
import '../ebook/epub_loader.dart';
import '../ebook/state/ebook_providers.dart';
import '../library/state/library_providers.dart';
import '../player/state/playback_controller.dart';
import '../settings/state/settings_providers.dart';
import 'ebook_spans.dart';
import 'link_providers.dart';
import 'link_switch.dart';
import 'read_along.dart';
import 'sync_strategy.dart';

/// A linked EPUB's paragraph texts and chapter spans, parsed once for the
/// read-along window (the same paragraph split the reader itself uses, so a
/// paragraph position means the same thing in both).
class BookText {
  const BookText(this.paragraphs, this.spans);

  final List<String> paragraphs;
  final List<ChapterSpan> spans;
}

final bookTextProvider = FutureProvider.autoDispose
    .family<BookText?, String>((ref, ebookId) async {
      final ebook = await ref.watch(itemDetailProvider(ebookId).future);
      if (ebook.ebookFile?.isEpub != true) return null;
      final file = await ref
          .read(ebookRepositoryProvider)
          .ensureLocalFile(ebook);
      final EpubBook book = await openEpubFile(file);
      final chapters = parseChapters(book);
      final paragraphs = parseParagraphs(chapters, book.Content);
      return BookText([
        for (final p in paragraphs.flatParagraphs) p.element.text.trim(),
      ], chapterSpansOfBook(book));
    });

/// The few lines of the book around where the audiobook is, scrolling with it
/// (Now Playing's "Read along"). Tapping opens the reader at that spot.
class ReadAlongWindow extends ConsumerWidget {
  const ReadAlongWindow({required this.audio, super.key});

  final LibraryItemDetail audio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final link = ref.watch(itemLinkProvider(audio.id)).valueOrNull;
    if (link == null || link.audioItemId != audio.id) {
      return const SizedBox.shrink();
    }
    final text = ref.watch(bookTextProvider(link.ebookItemId));
    final seconds = ref.watch(playbackPositionProvider).valueOrNull ?? 0;
    final mode = syncModeFromName(
      ref.watch(appSettingsProvider).valueOrNull?.linkSyncMode ?? 'estimated',
    );
    final theme = Theme.of(context);
    Widget content;
    final book = text.valueOrNull;
    if (text.isLoading) {
      content = const Center(child: CircularProgressIndicator());
    } else if (book == null || book.paragraphs.isEmpty) {
      content = const SizedBox.shrink();
    } else {
      final pos = followPosition(
        AudioPoint(seconds: seconds, spans: audioSpansOf(audio), mode: mode),
        book.spans,
        book.paragraphs.length,
      );
      if (pos == null) return const SizedBox.shrink();
      final at = pos.floor();
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = at - 1; i <= at + 1; i++)
            if (i >= 0 && i < book.paragraphs.length)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  book.paragraphs[i],
                  maxLines: i == at ? 6 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: i == at
                      ? theme.textTheme.bodyLarge
                      : theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                ),
              ),
        ],
      );
    }
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: InkWell(
        onTap: () async {
          final ebook = await ref.read(
            itemDetailProvider(link.ebookItemId).future,
          );
          if (!context.mounted) return;
          await switchToEbook(
            context,
            ref,
            audio: audio,
            ebook: ebook,
            audioSeconds: seconds,
          );
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: content),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () =>
                    ref.read(readAlongOpenProvider.notifier).state = false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
