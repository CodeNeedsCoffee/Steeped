import 'package:flutter_test/flutter_test.dart';
import 'package:steeped/features/linking/sync_anchors.dart';

void main() {
  const day = 36000.0; // a 10 hour book
  final a = SyncAnchor(.2, 7000);
  final b = SyncAnchor(.6, 22000);

  test('between two anchors it interpolates', () {
    expect(secondsFor([a, b], .4, day), closeTo(14500, 1));
    expect(wordFor([a, b], 14500, day), closeTo(.4, .001));
  });

  test('beside a lone anchor it leans on it, far from it it does not', () {
    expect(secondsFor([a], .25, day), closeTo(7000 + .05 * day, 1));
    expect(secondsFor([a], .5, day), isNull);
    expect(wordFor([a], 7000 + 1800, day), closeTo(.25, .001));
    expect(wordFor([a], 30000, day), isNull);
    expect(secondsFor(const [], .5, day), isNull);
  });

  test('a new anchor replaces crowded ones and ones that contradict it', () {
    final crowded = mergeAnchor([a, b], SyncAnchor(.201, 7100));
    expect(crowded.length, 2);
    expect(crowded.first.seconds, 7100);
    // An anchor later in the book but earlier in the audio cannot both be true.
    final contradiction = mergeAnchor([a, b], SyncAnchor(.7, 3000));
    expect(contradiction.map((x) => x.word), [.7]);
  });

  test('the list stays ordered and capped', () {
    var list = <SyncAnchor>[];
    for (var i = 0; i < 60; i++) {
      list = mergeAnchor(list, SyncAnchor(i / 100, i * 300.0));
    }
    expect(list.length, lessThanOrEqualTo(40));
    for (var i = 1; i < list.length; i++) {
      expect(list[i].word, greaterThan(list[i - 1].word));
    }
  });
}
