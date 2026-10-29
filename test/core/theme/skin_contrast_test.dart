import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steeped/core/theme/skin.dart';
import 'package:steeped/core/theme/skin_registry.dart';

double ratio(Color a, Color b) {
  final l1 = a.computeLuminance(), l2 = b.computeLuminance();
  final hi = l1 > l2 ? l1 : l2, lo = l1 > l2 ? l2 : l1;
  return (hi + .05) / (lo + .05);
}

void main() {
  const variants = [ThemeVariant.light, ThemeVariant.dark, ThemeVariant.black];

  for (final skin in availableSkins) {
    for (final v in variants) {
      group('${skin.id.name} / ${v.name}', () {
        final theme = skin.buildTheme(v);
        final s = theme.colorScheme;

        test('has the expected brightness', () {
          expect(
            s.brightness,
            v == ThemeVariant.light ? Brightness.light : Brightness.dark,
          );
        });

        test('body text on the scaffold meets WCAG AA (4.5:1)', () {
          expect(ratio(s.onSurface, s.surface), greaterThanOrEqualTo(4.5));
        });

        test('secondary text on the scaffold meets AA', () {
          expect(
            ratio(s.onSurfaceVariant, s.surface),
            greaterThanOrEqualTo(4.5),
          );
        });

        test('buttons: onPrimary on primary meets AA', () {
          expect(ratio(s.onPrimary, s.primary), greaterThanOrEqualTo(4.5));
        });

        test('accent text (primary) on the scaffold meets 3:1 (large/UI)', () {
          // Section headers and icons use the primary color.
          expect(ratio(s.primary, s.surface), greaterThanOrEqualTo(3.0));
        });

        test('error text on the scaffold meets AA', () {
          expect(ratio(s.error, s.surface), greaterThanOrEqualTo(4.5));
        });
      });
    }
  }

  for (final skin in availableSkins) {
    for (final v in variants) {
      test('${skin.id.name} / ${v.name}: mini-player text stays readable', () {
        final s = skin.buildTheme(v).colorScheme;
        final fill = Color.alphaBlend(
          s.primary.withValues(alpha: 0.22),
          s.surface,
        ).withValues(alpha: 0.88);
        final onScaffold = Color.alphaBlend(fill, s.surface);
        expect(ratio(s.onSurface, onScaffold), greaterThanOrEqualTo(4.5));
      });
    }
  }

  test('the black variant is truly darker than dark', () {
    for (final skin in availableSkins) {
      expect(
        skin.buildTheme(ThemeVariant.black).colorScheme.surface.computeLuminance(),
        lessThan(
          skin.buildTheme(ThemeVariant.dark).colorScheme.surface.computeLuminance(),
        ),
      );
    }
  });

  test('ThemeVariant.parse falls back to dark; system resolves by platform', () {
    expect(ThemeVariant.parse('nonsense'), ThemeVariant.dark);
    expect(ThemeVariant.system.resolve(Brightness.light), ThemeVariant.light);
    expect(ThemeVariant.system.resolve(Brightness.dark), ThemeVariant.dark);
    expect(ThemeVariant.black.resolve(Brightness.light), ThemeVariant.black);
  });
}
