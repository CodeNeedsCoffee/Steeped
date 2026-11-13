import 'dart:io';

// ignore: implementation_imports
import 'package:epub_view/epub_view.dart' show EpubBook, EpubChapter;

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

/// Spans for an EPUB that is already parsed (the reader has one open), in
/// table-of-contents order.
List<ChapterSpan> chapterSpansOfBook(EpubBook book) {
  final flat = <(String, int)>[];
  _flatten(book.Chapters ?? const [], flat);
  return spansFromWeights(flat);
}

/// Spans for the EPUB at [file]. Parses the whole book, so prefer
/// [chapterSpansOfBook] when it is already open.
Future<List<ChapterSpan>> epubChapterSpans(File file) async =>
    chapterSpansOfBook(await openEpubFile(file));

/// A book as the reader sees it, in paragraphs, converted to words: how far a
/// place is through the text (0..1 by words, which tracks narration time far
/// better than paragraph counts or HTML size), where each chapter begins and
/// back. [wordCounts] is the words in each paragraph and [toc] the chapters
/// (title and first paragraph).
class ParagraphMap {
  ParagraphMap(List<int> wordCounts, List<({String title, int start})> toc)
    : _words = wordCounts,
      _before = List<int>.filled(wordCounts.length + 1, 0) {
    for (var p = 0; p < wordCounts.length; p++) {
      _before[p + 1] = _before[p] + wordCounts[p];
    }
    final chapters = <({String title, int start})>[];
    for (final c in toc) {
      final start = c.start.clamp(0, wordCounts.length);
      if (chapters.isNotEmpty && chapters.last.start == start) {
        chapters[chapters.length - 1] = (title: c.title, start: start);
      } else if (chapters.isEmpty || start > chapters.last.start) {
        chapters.add((title: c.title, start: start));
      }
    }
    final total = _before.last.toDouble();
    spans = [];
    if (total > 0) {
      if (chapters.isEmpty || chapters.first.start > 0) {
        final end = chapters.isEmpty
            ? total
            : _before[chapters.first.start].toDouble();
        spans.add(ChapterSpan('', 0, end / total));
      }
      for (var i = 0; i < chapters.length; i++) {
        final from = _before[chapters[i].start].toDouble();
        final to = i + 1 < chapters.length
            ? _before[chapters[i + 1].start].toDouble()
            : total;
        spans.add(ChapterSpan(chapters[i].title, from / total, to / total));
      }
    }
  }

  final List<int> _words;
  final List<int> _before;

  /// Chapters in 0..1 of the book's words.
  late final List<ChapterSpan> spans;

  int get paragraphCount => _words.length;
  int get totalWords => _before.last;

  /// 0..1 through the book's words for a place given as paragraph index plus
  /// how far into it.
  double wordFraction(double paragraphPos) {
    if (totalWords <= 0 || _words.isEmpty) return 0;
    final p = paragraphPos.floor().clamp(0, _words.length - 1);
    final within = (paragraphPos - p).clamp(0.0, 1.0);
    return ((_before[p] + _words[p] * within) / totalWords).clamp(0.0, 1.0);
  }

  /// The place (paragraph index plus how far into it) at [fraction] of the
  /// book's words.
  double paragraphPos(double fraction) {
    if (totalWords <= 0 || _words.isEmpty) return 0;
    final target = fraction.clamp(0.0, 1.0) * totalWords;
    var lo = 0, hi = _words.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) ~/ 2;
      if (_before[mid] <= target) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    final w = _words[lo];
    return lo + (w == 0 ? 0 : ((target - _before[lo]) / w).clamp(0.0, 0.999));
  }
}
