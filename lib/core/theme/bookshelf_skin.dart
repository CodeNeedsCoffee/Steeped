import 'package:flutter/material.dart';

import 'app_skin_style.dart';
import 'app_theme.dart';
import 'skin.dart';

/// PLAN.md Phase 2.3: warm wood/paper tones, skeuomorphic shelf styling —
/// no frosted surfaces (opaque wood-toned cards instead), sharper/smaller
/// radii than glass-modern to read as "carved" rather than "app-like".
class BookshelfSkin extends Skin {
  const BookshelfSkin();

  @override
  SkinId get id => SkinId.bookshelf;

  @override
  ThemeData buildTheme([ThemeVariant variant = ThemeVariant.dark]) {
    const seedColor = Color(0xFFB07D4F); // warm wood brown
    final isLight = variant == ThemeVariant.light;
    final isBlack = variant == ThemeVariant.black;
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: isLight ? Brightness.light : Brightness.dark,
        ).copyWith(
          surface: switch (variant) {
            ThemeVariant.light => const Color(0xFFF6EEDF), // paper
            ThemeVariant.black => const Color(0xFF0B0805),
            _ => const Color(0xFF241A12),
          },
          surfaceContainerHighest: switch (variant) {
            ThemeVariant.light => const Color(0xFFE8D9BE),
            ThemeVariant.black => const Color(0xFF241A12),
            _ => const Color(0xFF3A2A1B),
          },
        );
    final cardColor = colorScheme.surfaceContainerHighest;

    return ThemeData(
      useMaterial3: true,
      brightness: colorScheme.brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      extensions: const [
        AppSpacing(),
        AppRadii(sm: 4, md: 6, lg: 10),
        AppSkinStyle(
          useFrostedSurfaces: false,
          blurSigma: 0,
          coverStyle: CoverStyle.bookSpine,
        ),
      ],
      appBarTheme: AppBarTheme(
        backgroundColor: switch (variant) {
          ThemeVariant.light => const Color(0xFFDCC7A0),
          ThemeVariant.black => const Color(0xFF000000),
          _ => const Color(0xFF1B130D),
        },
        foregroundColor: isLight ? const Color(0xFF2A1F14) : null,
        elevation: 2,
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: isBlack ? 0 : 3,
        shadowColor: Colors.black.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      dividerTheme: DividerThemeData(
        color: isLight ? const Color(0xFFCDB894) : const Color(0xFF4A3624),
      ),
    );
  }
}
