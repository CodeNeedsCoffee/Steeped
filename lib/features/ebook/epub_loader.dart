import 'dart:io';

// ignore: implementation_imports
import 'package:epub_view/epub_view.dart' show EpubBook, EpubChapter, EpubReader;

/// `epub_view` builds its pages from the table of contents only, so a spine
/// file the contents never mentions is dropped. Some books split every chapter
/// into a heading file and a body file and list only the heading (Alchemised:
/// `chapter069_split_000.xhtml` is "CHAPTER 69", `_split_001` is the text), so
/// the reader showed nothing but headings.
///
/// For each contents entry, the spine files that follow its file and are not
/// themselves in the contents are appended to that entry's HTML. [spineFiles]
/// are content-file names in reading order; [bodyOf] returns a file's HTML.
void mergeUnlistedSpineFiles({
  required List<String> spineFiles,
  required String? Function(String file) bodyOf,
  required List<EpubChapter> chapters,
}) {
  final listed = {
    for (final c in chapters)
      if (c.ContentFileName != null) c.ContentFileName!,
  };
  // The first entry per file is the one `epub_view` parses, so it gets the
  // trailing files.
  final owner = <String, EpubChapter>{};
  for (final c in chapters) {
    final f = c.ContentFileName;
    if (f != null) owner.putIfAbsent(f, () => c);
  }
  for (var i = 0; i < spineFiles.length; i++) {
    final chapter = owner[spineFiles[i]];
    if (chapter == null) continue;
    final extra = StringBuffer();
    for (var j = i + 1; j < spineFiles.length; j++) {
      if (listed.contains(spineFiles[j])) break;
      final html = bodyOf(spineFiles[j]);
      if (html != null) extra.write(_bodyInner(html));
    }
    if (extra.isEmpty) continue;
    final own = chapter.HtmlContent ?? '';
    final end = own.toLowerCase().lastIndexOf('</body>');
    chapter.HtmlContent = end == -1
        ? '$own$extra'
        : '${own.substring(0, end)}$extra${own.substring(end)}';
  }
}

String _bodyInner(String html) {
  final m = RegExp(
    r'<body[^>]*>([\s\S]*)</body>',
    caseSensitive: false,
  ).firstMatch(html);
  return m == null ? html : m.group(1)!;
}

/// Reads the EPUB at [file] and folds unlisted spine files into the chapters.
Future<EpubBook> openEpubFile(File file) async {
  final book = await EpubReader.readBook(await file.readAsBytes());
  final package = book.Schema?.Package;
  final hrefById = {
    for (final m in package?.Manifest?.Items ?? const [])
      if (m.Id != null && m.Href != null) m.Id!: m.Href!,
  };
  final html = book.Content?.Html ?? const {};
  final spine = <String>[
    for (final ref in package?.Spine?.Items ?? const [])
      if (hrefById[ref.IdRef] case final href? when html.containsKey(href))
        href,
  ];
  final flat = <EpubChapter>[];
  void walk(List<EpubChapter> list) {
    for (final c in list) {
      flat.add(c);
      walk(c.SubChapters ?? const []);
    }
  }

  walk(book.Chapters ?? const []);
  mergeUnlistedSpineFiles(
    spineFiles: spine,
    bodyOf: (f) => html[f]?.Content,
    chapters: flat,
  );
  return book;
}
