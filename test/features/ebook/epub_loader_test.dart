import 'package:epub_view/epub_view.dart' show EpubChapter;
import 'package:flutter_test/flutter_test.dart';
import 'package:steeped/features/ebook/epub_loader.dart';

EpubChapter ch(String file, String html) => EpubChapter()
  ..Title = file
  ..ContentFileName = file
  ..HtmlContent = html
  ..SubChapters = [];

String doc(String body) => '<html><body>$body</body></html>';

void main() {
  test('a body file the contents never lists is appended to its heading', () {
    final chapters = [
      ch('c1_000', doc('<h1>CHAPTER 1</h1>')),
      ch('c2_000', doc('<h1>CHAPTER 2</h1>')),
    ];
    final files = {
      'c1_001': doc('<p>one text</p>'),
      'c2_001': doc('<p>two text</p>'),
    };
    mergeUnlistedSpineFiles(
      spineFiles: ['c1_000', 'c1_001', 'c2_000', 'c2_001'],
      bodyOf: (f) => files[f],
      chapters: chapters,
    );
    expect(chapters[0].HtmlContent, contains('CHAPTER 1'));
    expect(chapters[0].HtmlContent, contains('one text'));
    expect(chapters[0].HtmlContent, isNot(contains('two text')));
    expect(chapters[1].HtmlContent, contains('two text'));
    // The extra HTML stays inside the body, not after </html>.
    expect(chapters[0].HtmlContent!.trimRight(), endsWith('</body></html>'));
  });

  test('several unlisted files in a row are all added, in order', () {
    final chapters = [ch('a', doc('<h1>A</h1>')), ch('z', doc('<h1>Z</h1>'))];
    final files = {'b': doc('<p>B</p>'), 'c': doc('<p>C</p>')};
    mergeUnlistedSpineFiles(
      spineFiles: ['a', 'b', 'c', 'z'],
      bodyOf: (f) => files[f],
      chapters: chapters,
    );
    final html = chapters[0].HtmlContent!;
    expect(html.indexOf('<p>B</p>'), lessThan(html.indexOf('<p>C</p>')));
  });

  test('a book whose contents list every file is left alone', () {
    final chapters = [ch('a', doc('<p>A</p>')), ch('b', doc('<p>B</p>'))];
    final before = [for (final c in chapters) c.HtmlContent];
    mergeUnlistedSpineFiles(
      spineFiles: ['a', 'b'],
      bodyOf: (_) => doc('<p>never</p>'),
      chapters: chapters,
    );
    expect([for (final c in chapters) c.HtmlContent], before);
  });

  test('spine files before the first entry are not attached anywhere', () {
    final chapters = [ch('a', doc('<p>A</p>'))];
    mergeUnlistedSpineFiles(
      spineFiles: ['cover', 'a'],
      bodyOf: (f) => doc('<p>$f</p>'),
      chapters: chapters,
    );
    expect(chapters[0].HtmlContent, isNot(contains('cover')));
  });

  test('files after the last entry go to that entry', () {
    final chapters = [ch('a', doc('<p>A</p>'))];
    mergeUnlistedSpineFiles(
      spineFiles: ['a', 'end'],
      bodyOf: (f) => doc('<p>$f</p>'),
      chapters: chapters,
    );
    expect(chapters[0].HtmlContent, contains('<p>end</p>'));
  });
}
