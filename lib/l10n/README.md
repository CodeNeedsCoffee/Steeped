# Localization

User-facing text lives in `app_en.arb` (the template) and is read through
`context.l10n`:

```dart
import '../../l10n/l10n.dart';
Text(context.l10n.settings)
```

Only **en-US ships today**. The Language row in Settings stays English-only
until a second ARB exists.

## Adding or changing text

1. Add the key to `app_en.arb` (use ICU for plurals, e.g.
   `{count, plural, =1{1 book} other{{count} books}}`, and give every
   placeholder a type under `"@key"`).
2. Run `flutter gen-l10n`.
3. Use `context.l10n.yourKey` in code.

`test/l10n/no_hardcoded_strings_test.dart` fails if a string literal is
passed straight to `Text(...)`, `tooltip:`, `labelText:`, `hintText:`, etc.,
and if an ARB key is unused. Dates and weekday names use `intl`'s
`DateFormat` with the current locale, not hand-written strings.

Enum names shown in the UI are localized through `enum_labels.dart`; the
enums themselves hold no English.

## Adding a language

1. Copy `app_en.arb` to `app_xx.arb` (e.g. `app_de.arb`), change `@@locale`,
   and translate the values. Keep the keys and placeholders identical. The
   test above fails if keys are missing or extra.
2. Run `flutter gen-l10n`. The new locale is picked up automatically via
   `AppLocalizations.supportedLocales`, which `MaterialApp` already uses.
3. Replace the static Language row in `settings_screen.dart` with a picker over
   `AppLocalizations.supportedLocales` and persist the choice in
   `AppSettings` (a nullable `localeCode`, null = follow the system).

## Known gaps (not yet localized)

- Android Auto browse titles (`car_content_tree.dart`) and the lock-screen
  action labels (`steeped_audio_handler.dart`) have no `BuildContext`; they need
  a locale lookup that doesn't depend on the widget tree.
- Foreground-service notification channel name in `main.dart`.
- Fallback names such as "Untitled" / "Unknown" in `lib/models/`.
- Log messages (developer-facing, intentionally English).
