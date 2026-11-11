import 'package:epub_view/epub_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steeped/features/ebook/epub_cfi_fix.dart';

EpubBook _book() {
  final package = EpubPackage()
    ..Manifest = (EpubManifest()
      ..Items = [
        EpubManifestItem()
          ..Id = 'cover'
          ..Href = 'cover.xhtml',
        EpubManifestItem()
          ..Id = 'item4'
          ..Href = 'OEBPS/ch-0.xhtml',
        EpubManifestItem()
          ..Id = 'item5'
          ..Href = 'OEBPS/ch-1.xhtml',
      ])
    ..Spine = (EpubSpine()
      ..Items = [
        EpubSpineItemRef()..IdRef = 'cover',
        EpubSpineItemRef()..IdRef = 'item4',
        EpubSpineItemRef()..IdRef = 'item5',
      ]);
  return EpubBook()..Schema = (EpubSchema()..Package = package);
}

List<EpubChapter> _chapters() => [
  EpubChapter()
    ..Anchor = 'a0'
    ..ContentFileName = 'ch-0.xhtml',
  EpubChapter()
    ..Anchor = 'a1'
    ..ContentFileName = 'ch-1.xhtml',
];

void main() {
  test(
    'rewrites the package step from the spine using the paragraph chapter',
    () {
      expect(
        fixSpineStep(
          'epubcfi(/6/0[wrong]!/4/2[x]/8)',
          _book(),
          _chapters(),
          fallbackChapterIndex: 1,
        ),
        'epubcfi(/6/6[item5]!/4/2[x]/8)',
      );
      expect(
        fixSpineStep(
          'epubcfi(/6/0[wrong]!/4/8)',
          _book(),
          _chapters(),
          fallbackChapterIndex: 0,
        ),
        'epubcfi(/6/4[item4]!/4/8)',
      );
    },
  );

  test('an anchor in the in-document part wins over the fallback', () {
    expect(
      fixSpineStep(
        'epubcfi(/6/0[last]!/4/2[a0]/8)',
        _book(),
        _chapters(),
        fallbackChapterIndex: 1,
      ),
      'epubcfi(/6/4[item4]!/4/2[a0]/8)',
    );
  });

  test('leaves other CFIs alone', () {
    for (final cfi in [
      'epubcfi(/6/18!/4/2[pgepubid00008]/2/1:0)',
      'epubcfi(/6/6[item5]!/4/8)',
      'not a cfi',
    ]) {
      expect(
        fixSpineStep(cfi, _book(), _chapters(), fallbackChapterIndex: 0),
        cfi,
      );
    }
  });

  test('no chapter to place it in: left as it was', () {
    const cfi = 'epubcfi(/6/0[missing]!/4/8)';
    expect(fixSpineStep(cfi, _book(), _chapters()), cfi);
    expect(
      fixSpineStep(cfi, _book(), _chapters(), fallbackChapterIndex: 9),
      cfi,
    );
  });
}
