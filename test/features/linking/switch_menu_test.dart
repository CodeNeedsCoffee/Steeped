import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steeped/features/linking/switch_menu.dart';
import 'package:steeped/features/settings/data/app_settings.dart';
import 'package:steeped/features/settings/state/settings_providers.dart';

class _Settings extends AppSettingsController {
  _Settings(this.value);
  final AppSettings value;
  @override
  Future<AppSettings> build() async => value;
}

Future<SwitchChoice?> _press(
  WidgetTester t,
  String mode, {
  bool playing = false,
  bool forceAsk = false,
  bool shown = false,
  String? tapLabel,
}) async {
  SwitchChoice? result;
  var done = false;
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        appSettingsProvider.overrideWith(
          () => _Settings(AppSettings(linkSwitchMode: mode)),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) {
              // Loaded before the press, as it is in the running app.
              ref.watch(appSettingsProvider);
              return Builder(
                builder: (button) => IconButton(
                  icon: const Icon(Icons.headphones),
                  onPressed: () async {
                    result = await chooseSwitch(
                      button,
                      ref,
                      switchLabel: 'Switch',
                      bothLabel: 'Both',
                      showPlayerLabel: 'Show player',
                      hidePlayerLabel: 'Hide player',
                      playerShown: shown,
                      alreadyPlaying: playing,
                      forceAsk: forceAsk,
                    );
                    done = true;
                  },
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  await t.tap(find.byIcon(Icons.headphones));
  await t.pumpAndSettle();
  if (tapLabel != null) {
    await t.tap(find.text(tapLabel));
    await t.pumpAndSettle();
  }
  expect(done || tapLabel == null, isTrue);
  return result;
}

void main() {
  testWidgets('ask shows both entries and returns the pick', (t) async {
    final r = await _press(t, 'ask', tapLabel: 'Both');
    expect(r, SwitchChoice.both);
  });

  testWidgets('ask lists the two entries', (t) async {
    await _press(t, 'ask');
    expect(find.text('Switch'), findsOneWidget);
    expect(find.text('Both'), findsOneWidget);
  });

  testWidgets('"switch" answers without a menu', (t) async {
    expect(await _press(t, 'switch'), SwitchChoice.switchOnly);
    expect(find.text('Both'), findsNothing);
  });

  testWidgets('"both" answers without a menu', (t) async {
    expect(await _press(t, 'both'), SwitchChoice.both);
  });

  testWidgets('a long-press asks even when a mode is set', (t) async {
    await _press(t, 'both', forceAsk: true);
    expect(find.text('Switch'), findsOneWidget);
  });

  testWidgets('already playing offers Show player and always asks', (t) async {
    final r = await _press(t, 'both', playing: true, tapLabel: 'Show player');
    expect(r, SwitchChoice.showPlayer);
  });

  testWidgets('a showing player offers Hide player instead', (t) async {
    final r = await _press(
      t,
      'both',
      playing: true,
      shown: true,
      tapLabel: 'Hide player',
    );
    expect(r, SwitchChoice.hidePlayer);
    expect(find.text('Show player'), findsNothing);
  });
}
