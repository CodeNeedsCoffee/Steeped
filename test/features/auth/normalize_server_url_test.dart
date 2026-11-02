import 'package:flutter_test/flutter_test.dart';
import 'package:steeped/features/auth/data/auth_repository.dart';

void main() {
  String n(String s, {String scheme = 'https'}) =>
      AuthRepository.normalizeServerUrl(s, defaultScheme: scheme);

  test('no scheme defaults to https', () {
    expect(n('audiobooks.dev'), 'https://audiobooks.dev');
    expect(n('  audiobooks.dev/ '), 'https://audiobooks.dev');
    expect(n('192.168.1.5:13378', scheme: 'http'), 'http://192.168.1.5:13378');
  });

  test('a typed scheme is kept, in any case, with or without slashes', () {
    expect(n('https://audiobooks.dev'), 'https://audiobooks.dev');
    expect(n('http://audiobooks.dev'), 'http://audiobooks.dev');
    expect(n('HTTPS://Audiobooks.dev'), 'https://Audiobooks.dev');
    expect(n('http:audiobooks.dev'), 'http://audiobooks.dev');
    expect(n('http:/audiobooks.dev'), 'http://audiobooks.dev');
  });

  test('trailing slashes are dropped, paths kept', () {
    expect(n('https://host///'), 'https://host');
    expect(n('host/abs/'), 'https://host/abs');
  });

  test('hasScheme', () {
    expect(AuthRepository.hasScheme('http://x'), isTrue);
    expect(AuthRepository.hasScheme(' HTTPS://x'), isTrue);
    expect(AuthRepository.hasScheme('httpbin.org'), isFalse);
  });
}
