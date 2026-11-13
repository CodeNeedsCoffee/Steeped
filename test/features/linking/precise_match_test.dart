import 'package:flutter_test/flutter_test.dart';
import 'package:steeped/features/linking/precise_match.dart';

void main() {
  guidedTests();
  matcherUpgradeTests();
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

  test('finds a paragraph from a real, badly heard clip (Alchemised)', () async {
    // What the phone's recogniser produced for 25 s of the audiobook: names and
    // endings wrong, a phrase repeated, the clip starting mid-sentence.
    const heard =
        "Even have got his corporation with Pal Palad palade Paladin is a "
        "critical source of lithium and it's Even have got his cooperation "
        "with Back to secure their interests on once that confident borrows "
        "weak they'll move quickly Back to secure their interests Ar Arrang "
        "Arranged";
    final paragraphs = [
      for (var i = 0; i < 900; i++)
        'she walked down the long grey corridor and counted doors $i',
    ];
    paragraphs[620] =
        '\u201cIt\u2019s all about striking at the right moment,\u201d Kaine was saying. '
        '\u201cThe surrounding countries will intervene soon. There are rumours of '
        'an alliance that even Hevgoss is cooperating with. Paladia\u2019s a critical '
        'source of lumithium, and it\u2019s an industrial power that isn\u2019t easily '
        'replaced. The other countries may not have cared when it was a civil '
        'conflict, but now they\u2019ll act to secure their interests. Once '
        'they\u2019re confident Morrough\u2019s weak, they\u2019ll move quickly.\u201d';
    // The estimate is 300 paragraphs out, past the first search radius.
    final r = await findParagraph(
      transcribe: (s, d) async => heard,
      seconds: 0,
      paragraphs: paragraphs,
      estimateIndex: 320,
    );
    expect(r!.paragraph, 620);
    expect(r.within, inInclusiveRange(0.2, 0.7));
  });
}

// A made-up book whose every word is unique (so a transcript says exactly
// where it came from) narrated at a steady rate.
String _word(int i) {
  var n = i;
  final c = StringBuffer();
  for (var k = 0; k < 4; k++) {
    c.writeCharCode(97 + n % 26);
    n ~/= 26;
  }
  return '${c}ing';
}

void guidedTests() {
  const wordsPerParagraph = 40;
  const wps = 2.4; // the narrator is a little slower than the 2.6 assumed
  final paragraphs = [
    for (var p = 0; p < 3000; p++)
      [
        for (var w = 0; w < wordsPerParagraph; w++)
          _word(p * wordsPerParagraph + w),
      ].join(' '),
  ];
  String heard(double start, double dur) => [
    for (var w = (start * wps).floor(); w < ((start + dur) * wps).floor(); w++)
      _word(w),
  ].join(' ');

  test(
    'guided search finds the audio time from a guess 10 minutes out',
    () async {
      const truth = 20000.0; // seconds
      final position = truth * wps / wordsPerParagraph; // paragraph index
      final calls = <double>[];
      final r = await findAudioSecondsGuided(
        transcribe: (s, d) async {
          calls.add(s);
          return heard(s, d);
        },
        estimate: truth + 600,
        paragraphs: paragraphs,
        position: position,
        target: speechWords(heard(truth, 20)),
        totalSeconds: 40000,
      );
      expect(r, isNotNull);
      expect(r!.seconds, closeTo(truth, 15));
      // Each listen halves the error at least; this one converges in a few.
      expect(calls.length, lessThanOrEqualTo(3));
    },
  );

  test(
    'guided search copes with a slow narrator and a guess 50 minutes out',
    () async {
      // The narrator reads 2.0 words/s but the search assumes 2.6.
      const slow = 2.0;
      String slowHeard(double start, double dur) => [
        for (
          var w = (start * slow).floor();
          w < ((start + dur) * slow).floor();
          w++
        )
          _word(w),
      ].join(' ');
      const truth = 30000.0;
      final calls = <double>[];
      final r = await findAudioSecondsGuided(
        transcribe: (s, d) async {
          calls.add(s);
          return slowHeard(s, d);
        },
        estimate: truth - 3000,
        paragraphs: paragraphs,
        position: truth * slow / wordsPerParagraph,
        target: speechWords(slowHeard(truth, 20)),
        totalSeconds: 50000,
      );
      expect(r!.seconds, closeTo(truth, 25));
      expect(calls.length, lessThanOrEqualTo(4));
    },
  );

  test(
    'guided search falls back to scanning when the first listen finds nothing',
    () async {
      const truth = 5000.0;
      var n = 0;
      final r = await findAudioSecondsGuided(
        transcribe: (s, d) async {
          // The first listen is unintelligible; later ones are fine.
          return n++ == 0 ? 'um uh er' : heard(s, d);
        },
        estimate: truth + 30,
        paragraphs: paragraphs,
        position: truth * wps / wordsPerParagraph,
        target: speechWords(heard(truth, 20)),
        totalSeconds: 40000,
      );
      expect(r!.seconds, closeTo(truth, 20));
    },
  );
}

void matcherUpgradeTests() {
  test('a unique passage has a clear margin, a repeated one has none', () {
    final unique = speechWords(
      'ruby jade blue gold iron opal ${'dust ' * 60} amber slate coral pearl onyx topaz',
    );
    final repeated = [
      ...speechWords('ruby jade blue gold iron opal'),
      ...speechWords('dust ' * 60),
      ...speechWords('ruby jade blue gold iron opal'),
    ];
    final needle = speechWords('ruby jade blue gold iron opal');
    expect(locateWords(unique, needle)!.margin, greaterThan(0.5));
    expect(locateWords(repeated, needle)!.margin, lessThan(0.1));
  });

  test('a run counts words in order, not scattered matches', () {
    final needle = speechWords('ruby jade blue gold iron opal');
    final inOrder = speechWords('x ruby jade blue gold iron opal y');
    final scattered = speechWords('ruby x jade y blue z gold w iron v opal');
    expect(locateWords(inOrder, needle)!.run, 6);
    expect(locateWords(scattered, needle)!.run, 1);
  });

  test('rare words weigh more than common ones across a book', () {
    final paragraphs = [
      for (var i = 0; i < 200; i++) 'the wind and the rain came down the hill',
      'zephyr quillon walked home',
    ];
    final book = BookIndex(paragraphs);
    expect(book.weight('quil'), greaterThan(book.weight('wind')));
    expect(book.wordsBefore(1), 9);
    expect(book.wordsIn(200), 4);
  });

  test(
    'a clip is judged as it arrives and the listen stops once sure',
    () async {
      final paragraphs = [
        for (var i = 0; i < 400; i++)
          [for (var w = 0; w < 30; w++) _word(i * 30 + w)].join(' '),
      ];
      const target = 250; // the narrator is at paragraph 250
      final spoken = paragraphs
          .sublist(target, target + 6)
          .join(' ')
          .split(' ');
      var asked = 0;
      double? stoppedAt;
      Future<String?> listen(
        double start,
        double max,
        bool Function(String, double) enough,
      ) async {
        asked++;
        // 2.4 words a second, delivered one second at a time.
        for (var sec = 1; sec <= max; sec++) {
          final text = spoken.take((sec * 2.4).floor()).join(' ');
          if (enough(text, sec.toDouble())) {
            stoppedAt = sec.toDouble();
            return text;
          }
        }
        return spoken.take((max * 2.4).floor()).join(' ');
      }

      final r = await findParagraph(
        listen: listen,
        seconds: 100,
        paragraphs: paragraphs,
        estimateIndex: 100, // the guess is far out
      );
      expect(r!.paragraph, 250);
      expect(asked, 1);
      // Far fewer than the full 25 s.
      expect(stoppedAt, lessThanOrEqualTo(10));
      expect(r.heardSeconds, lessThanOrEqualTo(10));
    },
  );

  test('an ambiguous short clip keeps listening to the full length', () async {
    // The same sentence appears at two places, so a short clip has no margin.
    const sentence = 'amber slate coral pearl onyx topaz quartz basalt garnet';
    final paragraphs = [
      for (var i = 0; i < 100; i++)
        'filler words number ${_word(i)} here again',
    ];
    paragraphs[10] = '$sentence then more of the quiet night went on and on';
    paragraphs[80] = '$sentence but afterwards the morning broke over the sea';
    double? stoppedAt;
    final r = await findParagraph(
      listen: (start, max, enough) async {
        const words =
            'amber slate coral pearl onyx topaz quartz basalt garnet then more of the quiet night went on and on';
        final all = words.split(' ');
        for (var sec = 1; sec <= max; sec++) {
          final text = all
              .take((sec * 1.0).floor().clamp(0, all.length))
              .join(' ');
          if (enough(text, sec.toDouble())) {
            stoppedAt = sec.toDouble();
            return text;
          }
        }
        return all.join(' ');
      },
      seconds: 0,
      paragraphs: paragraphs,
      estimateIndex: 10,
    );
    expect(r!.paragraph, 10);
    // It must not have stopped on the ambiguous first nine words.
    expect(stoppedAt == null || stoppedAt! > 9, isTrue);
  });
}
