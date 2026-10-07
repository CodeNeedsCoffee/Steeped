import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steeped/core/theme/glass_modern_skin.dart';

double _lum(Color c) => c.computeLuminance();
double _ratio(Color a, Color b) {
  final l1 = _lum(a), l2 = _lum(b);
  return (l1 > l2 ? l1 + .05 : l2 + .05) / (l1 > l2 ? l2 + .05 : l1 + .05);
}

void main() {
  test('glass mini-player fill stands out from the scaffold and keeps text readable', () {
    final scheme = const GlassModernSkin().buildTheme().colorScheme;
    final fill = Color.alphaBlend(
      scheme.primary.withValues(alpha: 0.22),
      scheme.surface,
    ).withValues(alpha: 0.88);
    final onScaffold = Color.alphaBlend(fill, scheme.surface);
    final bar = _ratio(onScaffold, scheme.surface);
    final text = _ratio(scheme.onSurface, onScaffold);
    debugPrint('bar vs scaffold=${bar.toStringAsFixed(2)} text=${text.toStringAsFixed(2)}');
    expect(bar, greaterThan(1.2));
    expect(text, greaterThan(4.5));
  });
}
