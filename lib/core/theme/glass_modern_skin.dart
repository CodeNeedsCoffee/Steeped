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
  String get displayName => 'Glass Modern';

  @override
  String get description =>
      'Frosted glass surfaces over a deep dark background, translucent '
      'cards.';

  @override
  ThemeData buildTheme() {
    const seedColor = Color(0xFF7FA8FF); // cool accent reads as "glass"
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
    ).copyWith(
      surface: const Color(0xFF12151B),
      surfaceContainerHighest: Colors.white.withValues(alpha: 0.08),
    );

    return ThemeData(
      useMaterial3: true,
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
        color: Colors.white.withValues(alpha: 0.06),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.08),
      ),
    );
  }
}
