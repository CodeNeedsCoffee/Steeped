import 'package:flutter_test/flutter_test.dart';
import 'package:steeped/features/ebook/data/ereader_settings.dart';
import 'package:steeped/features/ebook/data/reading_position.dart';
import 'package:steeped/models/media_progress.dart';

void main() {
  test('settings saved before the reading modes existed keep working', () {
    final s = EreaderSettings.fromJson({
      'fontFamily': 'serif',
      'fontScale': 1.4,
      'theme': 'black',
    });
    expect(s.fontScale, 1.4);
    expect(s.epubFlow, ReadingFlow.paged);
    expect(s.pdfFlow, ReadingFlow.paged);
    expect(s.comicFlow, ReadingFlow.scroll);
    expect(s.keepScreenOn, isTrue);
    expect(s.margin, 16);
  });

  test('settings round-trip through JSON', () {
    const s = EreaderSettings(
      epubFlow: ReadingFlow.scroll,
      comicFlow: ReadingFlow.paged,
      justify: true,
      brightness: 0.5,
    );
    final back = EreaderSettings.fromJson(s.toJson());
    expect(back.epubFlow, ReadingFlow.scroll);
    expect(back.comicFlow, ReadingFlow.paged);
    expect(back.justify, isTrue);
    expect(back.brightness, 0.5);
  });

  test('position, bookmark and highlight JSON round-trip', () {
    final p = ReadingPosition(
      location: 'epubcfi(/6/4)',
      fraction: 0.4,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(1000),
    );
    expect(ReadingPosition.fromJson(p.toJson()).location, 'epubcfi(/6/4)');
    final h = EbookHighlight(
      paragraph: 7,
      text: 'a line',
      createdAt: DateTime.fromMillisecondsSinceEpoch(5),
    );
    expect(EbookHighlight.fromJson(h.toJson()).paragraph, 7);
  });

  test('server progress carries lastUpdate for newest-wins resume', () {
    final p = MediaProgress.fromJson({
      'ebookLocation': 12,
      'ebookProgress': 0.3,
      'lastUpdate': 1700000000000,
    });
    expect(p.ebookLocation, '12');
    expect(p.lastUpdate, DateTime.fromMillisecondsSinceEpoch(1700000000000));
    expect(MediaProgress.fromJson({}).lastUpdate, isNull);
  });
}
