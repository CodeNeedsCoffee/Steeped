import 'package:flutter_test/flutter_test.dart';
import 'package:steeped/features/linking/ebook_spans.dart';

void main() {
  test('spans are proportional to text length and cover 0..1', () {
    final s = spansFromWeights([('A', 100), ('B', 300), ('C', 600)]);
    expect(s.first.start, 0);
    expect(s[1].start, closeTo(0.1, 1e-9));
    expect(s[2].start, closeTo(0.4, 1e-9));
    expect(s.last.end, closeTo(1.0, 1e-9));
  });

  test('an empty chapter still gets a sliver and order is kept', () {
    final s = spansFromWeights([('A', 0), ('B', 10)]);
    expect(s[0].end, lessThan(s[1].end));
    expect(s[0].length, greaterThan(0));
  });

  test('no chapters gives no spans', () {
    expect(spansFromWeights(const []), isEmpty);
  });
}
