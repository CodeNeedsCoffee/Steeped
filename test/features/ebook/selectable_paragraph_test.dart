import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' show parseFragment;
import 'package:html/dom.dart' as dom;
import 'package:steeped/features/ebook/selectable_paragraph.dart';

dom.Element _el(String html) =>
    parseFragment(html).nodes.whereType<dom.Element>().first;

Widget _host(Widget child, {ValueChanged<String?>? onSelected}) => MaterialApp(
  home: Scaffold(
    body: SelectionArea(
      onSelectionChanged: (c) => onSelected?.call(c?.plainText),
      child: ListView(children: [child]),
    ),
  ),
);

SelectableParagraph _para(String html, {ValueChanged<String>? onLink}) =>
    SelectableParagraph(
      html: html,
      style: const TextStyle(fontSize: 18),
      padding: EdgeInsets.zero,
      justify: false,
      onLink: onLink,
      index: 0,
    );

void main() {
  group('isSelectableParagraph', () {
    test('plain and inline-formatted paragraphs qualify', () {
      expect(isSelectableParagraph(_el('<p>Call me Ishmael.</p>')), isTrue);
      expect(
        isSelectableParagraph(
          _el('<p>Some <i>words</i> and <a href="x">a link</a><br/>end</p>'),
        ),
        isTrue,
      );
    });

    test('images, headings, lists and tables stay on Html', () {
      expect(
        isSelectableParagraph(_el('<p>text <img src="a.png"/></p>')),
        isFalse,
      );
      expect(isSelectableParagraph(_el('<h2>Chapter</h2>')), isFalse);
      expect(isSelectableParagraph(_el('<ul><li>a</li></ul>')), isFalse);
      expect(
        isSelectableParagraph(
          _el('<div><table><tr><td>a</td></tr></table></div>'),
        ),
        isFalse,
      );
    });
  });

  testWidgets('text can be selected inside a SelectionArea', (tester) async {
    String? selected;
    await tester.pumpWidget(
      _host(
        _para('<p>Beaufort had saved a very small sum of money</p>'),
        onSelected: (s) => selected = s,
      ),
    );
    await tester.pumpAndSettle();
    // Press on the first word rather than the middle of the line.
    final gesture = await tester.startGesture(
      tester.getTopLeft(find.byType(Text)) + const Offset(20, 9),
    );
    await tester.pump(const Duration(milliseconds: 900));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(selected, 'Beaufort');
  });

  testWidgets('collapses whitespace and trims the edges like HTML', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(_para('<p>\n   one   two\n  <b> three </b>  </p>')),
    );
    final text = tester.widget<Text>(find.byType(Text));
    expect(text.textSpan!.toPlainText(), 'one two three');
  });

  testWidgets('a mark becomes a highlight background', (tester) async {
    await tester.pumpWidget(
      _host(_para('<p>before <mark>marked</mark> after</p>')),
    );
    final text = tester.widget<Text>(find.byType(Text));
    final spans = (text.textSpan! as TextSpan).children!.cast<TextSpan>();
    final marked = spans.firstWhere((s) => s.text == 'marked');
    expect(marked.style?.backgroundColor, const Color(0x66FFC83D));
    expect(spans.first.style?.backgroundColor, isNull);
  });

  testWidgets('links stay tappable', (tester) async {
    String? tapped;
    await tester.pumpWidget(
      _host(
        _para(
          '<p>see <a href="ch2.xhtml">chapter two</a></p>',
          onLink: (h) => tapped = h,
        ),
      ),
    );
    final text = tester.widget<Text>(find.byType(Text));
    final link = (text.textSpan! as TextSpan).children!
        .cast<TextSpan>()
        .firstWhere((s) => s.text == 'chapter two');
    (link.recognizer! as dynamic).onTap();
    expect(tapped, 'ch2.xhtml');
  });

  testWidgets('a highlight finds the paragraph at the selection height', (
    tester,
  ) async {
    SelectableParagraph para(int i, String text) => SelectableParagraph(
      html: '<p>$text</p>',
      style: const TextStyle(fontSize: 18),
      padding: const EdgeInsets.only(bottom: 40),
      justify: false,
      index: i,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              para(0, 'fast hold of his mind that at the end'),
              para(1, 'possessed a mind of an uncommon mould'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final first = tester.getCenter(find.textContaining('fast hold')).dy;
    final second = tester.getCenter(find.textContaining('possessed')).dy;
    expect(paragraphIndexAtY(first, 'mind'), 0);
    expect(paragraphIndexAtY(second, 'mind'), 1);
    // The right height but text that is not in that paragraph: no match.
    expect(paragraphIndexAtY(second, 'hold of his'), isNull);
  });
}
