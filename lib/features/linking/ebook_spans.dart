import 'dart:io';

// ignore: implementation_imports
import 'package:epub_view/epub_view.dart' show EpubChapter;

import '../ebook/epub_loader.dart';

import 'sync_strategy.dart';

/// J3: chapter spans over 0..1 of a book, each chapter sized by its text
/// length (a chapter with no text still gets a sliver so spans stay ordered).
List<ChapterSpan> spansFromWeights(List<(String title, int weight)> chapters) {
  if (chapters.isEmpty) return const [];
  final weights = [for (final c in chapters) c.$2 < 1 ? 1 : c.$2];
  final total = weights.fold<int>(0, (a, b) => a + b);
  final spans = <ChapterSpan>[];
  var at = 0;
  for (var i = 0; i < chapters.length; i++) {
    final start = at / total;
    at += weights[i];
    spans.add(ChapterSpan(chapters[i].$1, start, at / total));
  }
  return spans;
}

void _flatten(List<EpubChapter> chapters, List<(String, int)> out) {
  for (final c in chapters) {
    out.add((c.Title ?? '', c.HtmlContent?.length ?? 0));
    _flatten(c.SubChapters ?? const [], out);
  }
}

/// Spans for the EPUB at [file], in table-of-contents order.
Future<List<ChapterSpan>> epubChapterSpans(File file) async {
  final book = await openEpubFile(file);
  final flat = <(String, int)>[];
  _flatten(book.Chapters ?? const [], flat);
  return spansFromWeights(flat);
}
