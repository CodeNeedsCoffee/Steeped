import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steeped/core/storage/app_database.dart';
import 'package:steeped/core/theme/skin.dart';
import 'package:steeped/core/theme/skin_registry.dart';
import 'package:steeped/features/settings/appearance_screen.dart';
import 'package:steeped/l10n/gen/app_localizations.dart';
import 'package:steeped/features/settings/settings_screen.dart';

/// QOL_PLAN F2: the busiest settings screens must lay out at large text
/// sizes without RenderFlex overflow (which Flutter reports as a test
/// exception).
void main() {
  for (final scale in [1.3, 2.0]) {
    for (final skin in availableSkins) {
      for (final variant in [ThemeVariant.light, ThemeVariant.black]) {
        for (final entry in {
          'SettingsScreen': () => const SettingsScreen(),
          'AppearanceScreen': () => const AppearanceScreen(),
        }.entries) {
          testWidgets(
            '${entry.key} at ${scale}x, ${skin.id.name}/${variant.name}',
            (tester) async {
              tester.view.physicalSize = const Size(360 * 3, 780 * 3);
              tester.view.devicePixelRatio = 3;
              addTearDown(tester.view.reset);
              final db = AppDatabase.forTesting(NativeDatabase.memory());
              addTearDown(db.close);

              await tester.pumpWidget(
                ProviderScope(
                  overrides: [appDatabaseProvider.overrideWithValue(db)],
                  child: MaterialApp(
                    localizationsDelegates: AppLocalizations.localizationsDelegates,
                    supportedLocales: AppLocalizations.supportedLocales,
                    theme: skin.buildTheme(variant),
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(textScaler: TextScaler.linear(scale)),
                      child: child!,
                    ),
                    home: entry.value(),
                  ),
                ),
              );
              await tester.pump(const Duration(milliseconds: 100));

              // Scroll the whole list so every tile is laid out.
              final list = find.byType(Scrollable).first;
              for (var i = 0; i < 40; i++) {
                await tester.drag(list, const Offset(0, -400));
                await tester.pump();
              }
              expect(tester.takeException(), isNull);

              // Let zero-duration provider timers drain before teardown.
              await tester.pumpWidget(const SizedBox());
              await tester.pump(const Duration(seconds: 1));
            },
          );
        }
      }
    }
  }
}
