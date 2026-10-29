import 'package:flutter/material.dart';

import 'app_skin_style.dart';
import 'app_theme.dart';
import 'skin.dart';

/// PLAN.md Phase 2.2: frosted surfaces, translucent cards, dark-first —
/// the app's primary/default look. Real frosting (`BackdropFilter` blur,
/// via [AppSkinStyle.useFrostedSurfaces] + `GlassSurface`) rather than just
/// a translucent color with no blur, which would just look flat.
class GlassModernSkin extends Skin {
  const GlassModernSkin();

  @override
  SkinId get id => SkinId.glassModern;

  @override
  ThemeData buildTheme([ThemeVariant variant = ThemeVariant.dark]) {
    const seedColor = Color(0xFF7FA8FF); // cool accent reads as "glass"
    final isLight = variant == ThemeVariant.light;
    // Translucent overlays are tinted with the text color so they read as
    // "lighter than the surface" on dark and "darker" on light.
    final ink = isLight ? Colors.black : Colors.white;
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: isLight ? Brightness.light : Brightness.dark,
        ).copyWith(
          surface: switch (variant) {
            ThemeVariant.light => const Color(0xFFF3F5FA),
            ThemeVariant.black => const Color(0xFF000000),
            _ => const Color(0xFF12151B),
          },
          surfaceContainerHighest: ink.withValues(alpha: isLight ? 0.07 : 0.08),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: colorScheme.brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      extensions: const [
        AppSpacing(),
        AppRadii(sm: 12, md: 18, lg: 28),
        AppSkinStyle(
          useFrostedSurfaces: true,
          blurSigma: 20,
          coverStyle: CoverStyle.modernCard,
        ),
      ],
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: ink.withValues(alpha: 0.06),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: ink.withValues(alpha: 0.10)),
        ),
      ),
      dividerTheme: DividerThemeData(color: ink.withValues(alpha: 0.08)),
    );
  }
}
