import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/skin_registry.dart';
import 'features/settings/data/app_settings.dart';
import 'features/settings/state/settings_providers.dart';
import 'l10n/gen/app_localizations.dart';

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
    return MaterialApp.router(
      title: 'Steeped',
      debugShowCheckedModeBanner: false,
      theme: skin.buildTheme(),
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
