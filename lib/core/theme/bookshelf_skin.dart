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
  String get displayName => 'Bookshelf';

  @override
  String get description =>
      'Warm wood and paper tones with book-spine styled covers.';

  @override
  ThemeData buildTheme() {
    const seedColor = Color(0xFFB07D4F); // warm wood brown
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
    ).copyWith(
      surface: const Color(0xFF241A12),
      surfaceContainerHighest: const Color(0xFF3A2A1B),
    );

    return ThemeData(
      useMaterial3: true,
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
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1B130D),
        elevation: 2,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF3A2A1B),
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFF4A3624)),
    );
  }
}
