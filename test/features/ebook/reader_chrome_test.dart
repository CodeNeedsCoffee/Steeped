import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steeped/features/ebook/data/ereader_settings.dart';
import 'package:steeped/features/ebook/reader_chrome.dart';
import 'package:steeped/l10n/gen/app_localizations.dart';

Widget _harness({
  required VoidCallback onPrev,
  required VoidCallback onNext,
  EreaderSettings settings = const EreaderSettings(),
}) =>
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ReaderChrome(
        settings: settings,
        onPrev: onPrev,
        onNext: onNext,
        // A SelectionArea body wins the gesture arena against an onTapUp,
        // which is what broke tap-to-turn in the EPUB reader.
        body: SelectionArea(
          child: SingleChildScrollView(
            child: Text('Call me Ishmael. ' * 400),
          ),
        ),
      ),
    );

void main() {
  testWidgets('edge taps turn the page over a SelectionArea body',
      (tester) async {
    var prev = 0, next = 0;
    await tester.pumpWidget(
      _harness(onPrev: () => prev++, onNext: () => next++),
    );
    final size = tester.getSize(find.byType(ReaderChrome));

    await tester.tapAt(Offset(size.width * 0.9, size.height * 0.5));
    await tester.pump(const Duration(milliseconds: 400));
    expect(next, 1);
    expect(prev, 0);

    await tester.tapAt(Offset(size.width * 0.1, size.height * 0.5));
    await tester.pump(const Duration(milliseconds: 400));
    expect(prev, 1);
  });

  testWidgets('tapToTurn off sends edge taps to the bar toggle',
      (tester) async {
    var turns = 0;
    await tester.pumpWidget(
      _harness(
        onPrev: () => turns++,
        onNext: () => turns++,
        settings: const EreaderSettings(tapToTurn: false),
      ),
    );
    final size = tester.getSize(find.byType(ReaderChrome));
    await tester.tapAt(Offset(size.width * 0.9, size.height * 0.5));
    await tester.pump(const Duration(milliseconds: 400));
    expect(turns, 0);
  });

  testWidgets('a drag is not a tap', (tester) async {
    var turns = 0;
    await tester.pumpWidget(
      _harness(onPrev: () => turns++, onNext: () => turns++),
    );
    final size = tester.getSize(find.byType(ReaderChrome));
    await tester.dragFrom(
      Offset(size.width * 0.9, size.height * 0.5),
      const Offset(0, -200),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(turns, 0);
  });
}
