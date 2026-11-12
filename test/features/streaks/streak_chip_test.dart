import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steeped/features/streaks/streak.dart';
import 'package:steeped/features/streaks/streak_chip.dart';
import 'package:steeped/l10n/gen/app_localizations.dart';

Widget host(StreakResult s) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: StreakChipView(streak: s, weekly: false)),
);

double opacityOf(WidgetTester t) => t
    .widget<Opacity>(
      find.descendant(
        of: find.byType(StreakChipView),
        matching: find.byType(Opacity),
      ),
    )
    .opacity;

void main() {
  testWidgets('no streak shows a dimmed 0, not nothing', (tester) async {
    await tester.pumpWidget(host(StreakResult.none));
    expect(find.text('0'), findsOneWidget);
    expect(find.byIcon(Icons.local_fire_department), findsOneWidget);
    expect(opacityOf(tester), lessThan(1));
  });

  testWidgets('a running streak is shown at full strength', (tester) async {
    await tester.pumpWidget(
      host(
        const StreakResult(
          current: 4,
          longest: 4,
          todayDone: true,
          atRisk: false,
          savedDays: 0,
        ),
      ),
    );
    expect(find.text('4'), findsOneWidget);
    expect(opacityOf(tester), 1);
  });
}
