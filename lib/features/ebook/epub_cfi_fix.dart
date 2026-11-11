// ignore: implementation_imports
import 'package:epub_view/epub_view.dart' show EpubBook, EpubChapter;

/// `epub_view` writes the package step of every CFI as `/6/0[<chapter anchor>]`:
/// step 0 and a table-of-contents anchor, where EPUB readers expect the spine
/// position (`/6/<2 * (index + 1)>[<idref>]`). The part after `!` is right.
/// Other readers (the official app, AudioBooth) resume from the package step,
/// so a position written with `/6/0` opens at the start of the book for them.
///
/// The anchor in that step is not trustworthy either (the package reports the
/// last chapter for most positions), so the chapter is taken from an anchor
/// that appears in the in-document part, else from [fallbackChapterIndex] (the
/// paragraph's own chapter). Returns [cfi] unchanged when it is not in the
/// `/6/0[...]` form or the chapter can't be placed in the spine.
String fixSpineStep(
  String cfi,
  EpubBook book,
  List<EpubChapter> chapters, {
  int? fallbackChapterIndex,
}) {
  final match = RegExp(r'^epubcfi\(/6/0\[[^\]]*\](!.*)\)$').firstMatch(cfi);
  if (match == null) return cfi;
  final rest = match.group(1)!;

  EpubChapter? chapter;
  for (final c in chapters) {
    if (c.Anchor != null && rest.contains('[${c.Anchor}]')) {
      chapter = c;
      break;
    }
  }
  if (chapter == null &&
      fallbackChapterIndex != null &&
      fallbackChapterIndex >= 0 &&
      fallbackChapterIndex < chapters.length) {
    chapter = chapters[fallbackChapterIndex];
  }
  final file = chapter?.ContentFileName;
  final package = book.Schema?.Package;
  if (file == null || package == null) return cfi;

  String base(String path) => path.split('/').last;
  final manifest = package.Manifest?.Items ?? const [];
  final item = manifest.where(
    (m) => m.Href != null && base(m.Href!) == base(file),
  );
  final id = item.isEmpty ? null : item.first.Id;
  final spine = package.Spine?.Items ?? const [];
  final at = spine.indexWhere((s) => s.IdRef == id);
  if (id == null || at < 0) return cfi;
  return 'epubcfi(/6/${(at + 1) * 2}[$id]$rest)';
}
