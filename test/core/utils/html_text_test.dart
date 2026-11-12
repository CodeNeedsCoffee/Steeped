import 'package:flutter_test/flutter_test.dart';
import 'package:steeped/core/utils/html_text.dart';

void main() {
  test('line breaks and paragraphs become newlines', () {
    expect(plainTextFromHtml('one<br />two<br>three'), 'one\ntwo\nthree');
    expect(plainTextFromHtml('<p>a</p><p>b</p>'), 'a\n\nb');
  });

  test('tags are dropped and entities decoded', () {
    expect(
      plainTextFromHtml('<i>Tom</i> &amp; Jerry &mdash; &quot;hi&quot;'),
      'Tom & Jerry — "hi"',
    );
  });

  test('plain text passes through unchanged', () {
    expect(plainTextFromHtml("It's plain."), "It's plain.");
  });

  test('runs of blank lines are collapsed and the ends trimmed', () {
    expect(plainTextFromHtml('<p>a</p><br /><br /><p>b</p>'), 'a\n\nb');
  });

  test('list items get bullets', () {
    expect(plainTextFromHtml('<ul><li>x</li><li>y</li></ul>'), '• x\n\n• y');
  });
}
