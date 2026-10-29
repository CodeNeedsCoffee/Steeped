import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:steeped/l10n/gen/app_localizations_en.dart';

void main() {
  final en = AppLocalizationsEn();

  test('plurals follow ICU rules', () {
    expect(en.bookCount(1), '1 book');
    expect(en.bookCount(0), '0 books');
    expect(en.bookCount(12), '12 books');
    expect(en.itemCountDuration(1, '2h 5m'), '1 item · 2h 5m');
    expect(en.streakDays(1), '1 day');
    expect(en.streakDays(3), '3 days');
    expect(en.updatesWaitingToSync(1), '1 update waiting to sync');
  });

  test('placeholders interpolate', () {
    expect(en.durationHoursMinutes(2, 5), '2h 5m');
    expect(en.pwTooShort(8), 'New password must be at least 8 characters.');
    expect(en.rewindSeconds(30), isNotEmpty);
  }, skip: false);

  test('every shipped locale has exactly the same keys as English', () {
    Set<String> keys(File f) => (jsonDecode(f.readAsStringSync()) as Map)
        .keys
        .cast<String>()
        .where((k) => !k.startsWith('@'))
        .toSet();
    final english = keys(File('lib/l10n/app_en.arb'));
    for (final f in Directory('lib/l10n').listSync().whereType<File>().where(
      (f) => RegExp(r'app_\w+\.arb$').hasMatch(f.path),
    )) {
      final other = keys(f);
      expect(
        other.difference(english),
        isEmpty,
        reason: '${f.path} has keys English lacks',
      );
      expect(
        english.difference(other),
        isEmpty,
        reason: '${f.path} is missing translations',
      );
    }
  });
}
