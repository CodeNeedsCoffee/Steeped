import 'package:flutter_test/flutter_test.dart';
import 'package:steeped/features/linking/link_switch.dart';
import 'package:steeped/features/linking/sync_strategy.dart';

void main() {
  const audio = [
    ChapterSpan('Chapter 1', 0, 600),
    ChapterSpan('Chapter 2', 600, 1200),
  ];
  const ebook = [
    ChapterSpan('Chapter One', 0, 0.4),
    ChapterSpan('Chapter Two', 0.4, 1.0),
  ];

  test('maps the audio position onto the ebook chapters', () {
    const p = AudioPoint(seconds: 900, spans: audio, mode: SyncMode.estimated);
    expect(p.fractionIn(ebook), closeTo(0.4 + 0.5 * 0.6, 1e-9));
  });

  test('sync Off, an unstarted book or no chapters map to nothing', () {
    expect(
      const AudioPoint(seconds: 900, spans: audio, mode: SyncMode.off)
          .fractionIn(ebook),
      isNull,
    );
    expect(
      const AudioPoint(seconds: 0, spans: audio, mode: SyncMode.estimated)
          .fractionIn(ebook),
      isNull,
    );
    expect(
      const AudioPoint(seconds: 10, spans: [], mode: SyncMode.estimated)
          .fractionIn(ebook),
      isNull,
    );
  });

  test('a PDF or comic (one span) maps by overall fraction', () {
    const p = AudioPoint(seconds: 300, spans: audio, mode: SyncMode.estimated);
    expect(p.fractionIn(const [ChapterSpan('', 0, 1)]), closeTo(0.25, 1e-9));
  });
}
