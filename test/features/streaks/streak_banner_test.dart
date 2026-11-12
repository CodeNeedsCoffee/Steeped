import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steeped/features/settings/data/app_settings.dart';
import 'package:steeped/features/settings/state/settings_providers.dart';
import 'package:steeped/features/streaks/streak.dart';
import 'package:steeped/features/streaks/streak_banner.dart';
import 'package:steeped/features/streaks/streak_providers.dart';
import 'package:steeped/l10n/gen/app_localizations.dart';

class _Settings extends AppSettingsController {
  _Settings(this.value);
  final AppSettings value;
  @override
  Future<AppSettings> build() async => value;
}

const atRisk = StreakResult(
  current: 4,
  longest: 4,
  todayDone: false,
  atRisk: true,
  savedDays: 0,
);

Widget host({
  required StreakResult streak,
  required DateTime now,
  AppSettings settings = const AppSettings(),
}) => ProviderScope(
  overrides: [
    appSettingsProvider.overrideWith(() => _Settings(settings)),
    streakProvider.overrideWith((ref) async => streak),
  ],
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: StreakBanner(now: now)),
  ),
);

void main() {
  final evening = DateTime(2026, 11, 12, 19);
  final morning = DateTime(2026, 11, 12, 9);

  testWidgets('shows in the evening when a streak is at risk', (t) async {
    await t.pumpWidget(host(streak: atRisk, now: evening));
    await t.pumpAndSettle();
    expect(find.textContaining('Keep your 4 days streak going'), findsOneWidget);
  });

  testWidgets('stays quiet in the morning', (t) async {
    await t.pumpWidget(host(streak: atRisk, now: morning));
    await t.pumpAndSettle();
    expect(find.textContaining('Keep your'), findsNothing);
  });

  testWidgets('hidden when the day is already done or the setting is off', (t) async {
    const done = StreakResult(
      current: 4, longest: 4, todayDone: true, atRisk: false, savedDays: 0,
    );
    await t.pumpWidget(host(streak: done, now: evening));
    await t.pumpAndSettle();
    expect(find.textContaining('Keep your'), findsNothing);

    await t.pumpWidget(
      host(streak: atRisk, now: evening, settings: const AppSettings(showStreak: false)),
    );
    await t.pumpAndSettle();
    expect(find.textContaining('Keep your'), findsNothing);
  });

  testWidgets('dismissing hides it for the day', (t) async {
    await t.pumpWidget(host(streak: atRisk, now: evening));
    await t.pumpAndSettle();
    await t.tap(find.byIcon(Icons.close));
    await t.pumpAndSettle();
    expect(find.textContaining('Keep your'), findsNothing);
  });
}
