import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steeped/features/ebook/data/ereader_settings.dart';
import 'package:steeped/features/ebook/reader_chrome.dart';
import 'package:steeped/features/linking/link_switch.dart';
import 'package:steeped/features/linking/read_along.dart';
import 'package:steeped/features/linking/reader_dock.dart';
import 'package:steeped/features/linking/sync_strategy.dart';
import 'package:steeped/features/settings/data/app_settings.dart';
import 'package:steeped/l10n/gen/app_localizations.dart';

void main() {
  // Audio: two chapters of 100 s and 300 s. Book: same titles, weights 1:3.
  const audioSpans = [ChapterSpan('One', 0, 100), ChapterSpan('Two', 100, 400)];
  const ebookSpans = [ChapterSpan('One', 0, .25), ChapterSpan('Two', .25, 1)];

  test('audio position maps to a paragraph position', () {
    final p = followPosition(
      const AudioPoint(
        seconds: 250,
        spans: audioSpans,
        mode: SyncMode.estimated,
      ),
      ebookSpans,
      1000,
    );
    // Halfway through chapter two = 62.5% of the book.
    expect(p, closeTo(625, 1));
  });

  test('no follow position when sync is off or the audio has not started', () {
    expect(
      followPosition(
        const AudioPoint(seconds: 250, spans: audioSpans, mode: SyncMode.off),
        ebookSpans,
        1000,
      ),
      isNull,
    );
    expect(
      followPosition(
        const AudioPoint(
          seconds: 0,
          spans: audioSpans,
          mode: SyncMode.estimated,
        ),
        ebookSpans,
        1000,
      ),
      isNull,
    );
  });

  test('play from here maps a paragraph back to audio time', () {
    final s = audioSecondsForParagraph(
      index: 625,
      paragraphCount: 1000,
      ebookSpans: ebookSpans,
      audioSpans: audioSpans,
      mode: SyncMode.estimated,
    );
    expect(s, closeTo(250, 1));
  });

  test('comfort zone leaves a paragraph in the middle alone', () {
    bool at(double top) =>
        inComfortZone(paragraphTop: top, bodyTop: 0, bodyHeight: 1000);
    expect(at(300), isTrue);
    expect(at(10), isFalse);
    expect(at(900), isFalse);
    expect(at(-50), isFalse);
  });

  test(
    'each direction has its own sync mode and the old single one carries over',
    () {
      const d = AppSettings();
      expect(
        (d.linkSyncToAudio, d.linkSyncToEbook),
        ('estimated', 'estimated'),
      );
      final split = AppSettings.fromJson(
        d
            .copyWith(linkSyncToAudio: 'estimated', linkSyncToEbook: 'precise')
            .toJson(),
      );
      expect(
        (split.linkSyncToAudio, split.linkSyncToEbook),
        ('estimated', 'precise'),
      );
      // A settings file from before the split: one value for both.
      final old = AppSettings.fromJson({'linkSyncMode': 'off'});
      expect((old.linkSyncToAudio, old.linkSyncToEbook), ('off', 'off'));
    },
  );

  test('the side panel needs a landscape phone or a tablet', () {
    expect(wideEnoughForPanel(411), isFalse);
    expect(wideEnoughForPanel(840), isTrue);
    expect(wideEnoughForPanel(720), isTrue);
  });

  test('chapter progress reports the time left in the chapter', () {
    final c = chapterProgressAt(audioSpans, 250)!;
    expect((c.title, c.left), ('Two', 150));
    expect(chapterProgressAt(audioSpans, 99)!.title, 'One');
    expect(chapterProgressAt(const [], 5), isNull);
  });

  test(
    'switch settings default to ask, follow and strip on, and round-trip',
    () {
      const d = AppSettings();
      expect((d.linkSwitchMode, d.linkFollow, d.linkDock), ('ask', true, true));
      final back = AppSettings.fromJson(
        d
            .copyWith(
              linkSwitchMode: 'both',
              linkFollow: false,
              linkDock: false,
            )
            .toJson(),
      );
      expect(
        (back.linkSwitchMode, back.linkFollow, back.linkDock),
        ('both', false, false),
      );
    },
  );

  testWidgets('the dock sits in the bottom bar and counts as covered', (
    tester,
  ) async {
    int? lastCovered;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ReaderChrome(
          settings: const EreaderSettings(),
          progress: .3,
          onPage: (d, covered) => lastCovered = covered.bottom.round(),
          dock: const SizedBox(key: Key('dock'), height: 52),
          body: const SizedBox.expand(),
        ),
      ),
    );
    expect(find.byKey(const Key('dock')), findsOneWidget);
    final size = tester.getSize(find.byType(ReaderChrome));
    await tester.tapAt(Offset(size.width * .9, size.height * .5));
    await tester.pump(const Duration(milliseconds: 400));
    // The bar is the slider row plus the 52 px dock, so more than the dock.
    expect(lastCovered, greaterThan(52));
  });
}
