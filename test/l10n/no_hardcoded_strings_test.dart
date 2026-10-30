import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// QOL_PLAN F4: user-facing text lives in lib/l10n/app_en.arb and is read
/// through `context.l10n`. This fails when a new string literal is passed
/// straight to a text-bearing widget or parameter.
///
/// To add UI text: add a key to app_en.arb, run `flutter gen-l10n`, and use
/// `context.l10n.yourKey`. Strings that are genuinely not for translation
/// (brand names, symbols) go in [_allowedLiterals].
final _patterns = <RegExp>[
  RegExp(r'''\bText\(\s*(?:const\s+)?['"]([^'"]*)['"]'''),
  RegExp(
    r'''\b(?:tooltip|labelText|hintText|helperText|semanticLabel|semanticsLabel|errorText)\s*:\s*['"]([^'"]*)['"]''',
  ),
  RegExp(r'''\b_snack\(\s*context\s*,\s*['"]([^'"]*)['"]'''),
  // Text(cond ? 'a' : 'b')
  RegExp(r'''\bText\([^;{}]*?\?\s*['"]([^'"]*)['"]\s*:\s*['"]'''),
];

/// Literals allowed to stay in code (never translated).
const _allowedLiterals = <String>{
  'Steeped',
};

void main() {
  test('no hard-coded user-facing strings outside the ARB', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.contains('/l10n/gen/')) continue;
      final source = entity.readAsStringSync();
      for (final pattern in _patterns) {
        for (final m in pattern.allMatches(source)) {
          final text = m.group(1) ?? '';
          // Pure symbols/punctuation/interpolation-only are not wording.
          if (!RegExp(r'[A-Za-z]{2,}').hasMatch(text)) continue;
          // Interpolation-only strings ('${n}%', '$count') carry no wording.
          if (text.trimLeft().startsWith(r'$')) continue;
          if (_allowedLiterals.contains(text)) continue;
          final line = '\n'.allMatches(source.substring(0, m.start)).length + 1;
          offenders.add('${entity.path}:$line  "$text"');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Move these into lib/l10n/app_en.arb and use context.l10n:\n'
          '${offenders.join('\n')}',
    );
  });

  test('every ARB message key is used in lib/', () {
    final arb = File('lib/l10n/app_en.arb').readAsStringSync();
    final keys = RegExp(r'^  "([a-zA-Z][A-Za-z0-9]*)":', multiLine: true)
        .allMatches(arb)
        .map((m) => m.group(1)!)
        .where((k) => !k.startsWith('@'))
        .toSet();
    final code = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.contains('/l10n/gen/'))
        .map((f) => f.readAsStringSync())
        .join('\n');
    final unused = [for (final k in keys) if (!code.contains('l10n.$k') && !code.contains('.$k')) k];
    expect(unused, isEmpty, reason: 'Unused ARB keys: $unused');
  });
}
