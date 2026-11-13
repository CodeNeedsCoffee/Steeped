import 'package:flutter_test/flutter_test.dart';
import 'package:steeped/features/linking/precise_match.dart';

void main() {
  const passage =
      'But the stork with her long bill tried in vain to partake of the '
      'savory broth. Her evident distress caused the sly fox much amusement.';

  test('speech words drop punctuation and apostrophes', () {
    expect(speechWords("The Fox's  tale, (told)!"), [
      'the',
      'foxs',
      'tale',
      'told',
    ]);
  });

  test('finds a passage in a noisy transcript', () {
    final hay = speechWords(
      'green krii com a aes but the stork with her long bill tried in vain '
      'to partake of the savory broth neck into which she could get her',
    );
    final loc = locateWords(hay, speechWords(passage).take(14).toList())!;
    expect(loc.score, greaterThan(0.7));
    // The passage begins at "but the stork" (index 6) or just after it.
    expect(loc.index, inInclusiveRange(6, 9));
  });

  test('an unrelated transcript scores low', () {
    final hay = speechWords(
      'chapter one the rain fell on the old harbour town ' * 3,
    );
    final loc = locateWords(hay, speechWords(passage).take(14).toList())!;
    expect(loc.score, lessThan(0.4));
  });

  test('ties go to the stretch nearest the preferred index', () {
    final one = speechWords('ruby jade blue gold iron opal');
    final hay = [...one, 'x', 'y', 'z', ...one];
    expect(locateWords(hay, one, prefer: 0)!.index, 0);
    expect(locateWords(hay, one, prefer: 9)!.index, 9);
  });

  test('audio search walks outwards until a window matches', () async {
    // The passage is spoken 70 s after the estimate.
    final probes = <double>[];
    Future<String?> transcribe(double start, double dur) async {
      probes.add(start);
      return (start <= 70 + 20 && start + dur >= 70 + 15)
          ? 'umm $passage and so on'
          : 'chapter one the rain fell on the old harbour town';
    }

    final r = await findAudioSeconds(
      transcribe: transcribe,
      estimate: 0,
      target: speechWords(passage),
      totalSeconds: 1000,
    );
    expect(r, isNotNull);
    expect(r!.seconds, closeTo(70, 40));
    expect(probes.length, greaterThan(1));
  });

  test('audio search gives up (null) when nothing matches', () async {
    final r = await findAudioSeconds(
      transcribe: (s, d) async =>
          'chapter one the rain fell on the old harbour',
      estimate: 100,
      target: speechWords(passage),
      totalSeconds: 1000,
    );
    expect(r, isNull);
  });

  test('audio search stops when recognition is unavailable', () async {
    var calls = 0;
    final r = await findAudioSeconds(
      transcribe: (s, d) async {
        calls++;
        return null;
      },
      estimate: 100,
      target: speechWords(passage),
      totalSeconds: 1000,
    );
    expect((r, calls), (null, 1));
  });

  test('finds the paragraph the audio is in', () async {
    final paragraphs = [
      for (var i = 0; i < 600; i++)
        'filler paragraph number $i about nothing at all here',
    ];
    paragraphs[320] = passage;
    final r = await findParagraph(
      transcribe: (s, d) async =>
          'but the stork with her long bill tried in vain to partake of the savory broth',
      seconds: 100,
      paragraphs: paragraphs,
      estimateIndex: 300,
    );
    expect(r!.paragraph, 320);
    expect(r.within, lessThan(0.3));
  });

  test('no paragraph when the clip is nearly silent', () async {
    final r = await findParagraph(
      transcribe: (s, d) async => 'uh',
      seconds: 1,
      paragraphs: const ['hello there'],
      estimateIndex: 0,
    );
    expect(r, isNull);
  });
}
