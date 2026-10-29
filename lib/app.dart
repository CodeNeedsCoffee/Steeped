import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/skin.dart';
import 'core/theme/skin_registry.dart';
import 'features/settings/data/app_settings.dart';
import 'features/settings/state/settings_providers.dart';
import 'l10n/l10n.dart';

class SteepedApp extends ConsumerWidget {
  const SteepedApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    // PLAN.md Phase 9.3: lock-orientation toggle.
    final settings =
        ref.watch(appSettingsProvider).valueOrNull ?? const AppSettings();
    SystemChrome.setPreferredOrientations(
      settings.lockPortrait
          ? [DeviceOrientation.portraitUp]
          : DeviceOrientation.values,
    );
    // PLAN.md Phase 2.4: the active skin, persisted alongside the rest of
    // AppSettings — same "just needs to be read here" pattern lockPortrait
    // already uses above.
    final skin = skinByName(settings.skinId);
    // QOL_PLAN F1: with "Follow system", `theme`/`darkTheme` + `themeMode`
    // let the OS flip light and dark without a rebuild of the settings.
    final variant = ThemeVariant.parse(settings.themeVariant);
    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appName,
      debugShowCheckedModeBanner: false,
      theme: skin.buildTheme(
        variant == ThemeVariant.system || variant == ThemeVariant.light
            ? ThemeVariant.light
            : variant,
      ),
      darkTheme: skin.buildTheme(
        variant == ThemeVariant.black ? ThemeVariant.black : ThemeVariant.dark,
      ),
      themeMode: switch (variant) {
        ThemeVariant.system => ThemeMode.system,
        ThemeVariant.light => ThemeMode.light,
        _ => ThemeMode.dark,
      },
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
