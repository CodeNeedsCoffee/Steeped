import 'package:flutter_test/flutter_test.dart';
import 'package:steeped/core/audio/voice_search.dart';

void main() {
  const books = [
    VoiceCandidate(id: 'a', title: 'The Way of Kings', author: 'Brandon Sanderson'),
    VoiceCandidate(id: 'b', title: 'Words of Radiance', author: 'Brandon Sanderson'),
    VoiceCandidate(id: 'c', title: 'Kings of the Wyld', author: 'Nicholas Eames'),
    VoiceCandidate(id: 'd', title: 'Dune', author: 'Frank Herbert'),
  ];

  test('strips spoken filler', () {
    expect(cleanVoiceQuery('Play the audiobook Dune'), 'dune');
    expect(cleanVoiceQuery('play me the book called Dune'), 'dune');
    expect(cleanVoiceQuery('Listen to Words of Radiance!'), 'words of radiance');
    expect(cleanVoiceQuery('play'), '');
  });

  test('exact title beats partial', () {
    expect(pickVoiceMatch('play Kings of the Wyld', books), 'c');
    expect(pickVoiceMatch('play the way of kings', books), 'a');
  });

  test('partial title still finds the book', () {
    expect(pickVoiceMatch('play words of radiance', books), 'b');
    expect(pickVoiceMatch('play radiance', books), 'b');
  });

  test('"<title> by <author>" uses the author to break ties', () {
    const dupes = [
      VoiceCandidate(id: 'x', title: 'Foundation', author: 'Someone Else'),
      VoiceCandidate(id: 'y', title: 'Foundation', author: 'Isaac Asimov'),
    ];
    expect(pickVoiceMatch('play Foundation by Isaac Asimov', dupes), 'y');
  });

  test('author-only query matches that author\'s first book', () {
    expect(pickVoiceMatch('play Frank Herbert', books), 'd');
  });

  test('no plausible match returns null', () {
    expect(pickVoiceMatch('play something that does not exist', books), isNull);
    expect(pickVoiceMatch('play', books), isNull);
  });
}
