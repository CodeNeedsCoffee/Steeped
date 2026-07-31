import 'package:flutter/material.dart';

/// Design tokens shared by every screen. This is deliberately minimal for
/// now — a single default look, just enough for real screens to render
/// consistently. The full skin engine (glass-modern + bookshelf skins,
/// runtime switching) is built in Milestone 3 (PLAN.md Phase 2) against
/// these same token slots.
@immutable
class AppSpacing extends ThemeExtension<AppSpacing> {
  const AppSpacing({
    this.xs = 4,
    this.sm = 8,
    this.md = 16,
    this.lg = 24,
    this.xl = 32,
  });

  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;

  @override
  AppSpacing copyWith({double? xs, double? sm, double? md, double? lg, double? xl}) {
    return AppSpacing(
      xs: xs ?? this.xs,
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
      xl: xl ?? this.xl,
    );
  }

  @override
  AppSpacing lerp(ThemeExtension<AppSpacing>? other, double t) {
    if (other is! AppSpacing) return this;
    return AppSpacing(
      xs: lerpDouble(xs, other.xs, t),
      sm: lerpDouble(sm, other.sm, t),
      md: lerpDouble(md, other.md, t),
      lg: lerpDouble(lg, other.lg, t),
      xl: lerpDouble(xl, other.xl, t),
    );
  }

  static double lerpDouble(double a, double b, double t) => a + (b - a) * t;
}

@immutable
class AppRadii extends ThemeExtension<AppRadii> {
  const AppRadii({this.sm = 8, this.md = 12, this.lg = 20});

  final double sm;
  final double md;
  final double lg;

  @override
  AppRadii copyWith({double? sm, double? md, double? lg}) {
    return AppRadii(sm: sm ?? this.sm, md: md ?? this.md, lg: lg ?? this.lg);
  }

  @override
  AppRadii lerp(ThemeExtension<AppRadii>? other, double t) {
    if (other is! AppRadii) return this;
    return AppRadii(
      sm: AppSpacing.lerpDouble(sm, other.sm, t),
      md: AppSpacing.lerpDouble(md, other.md, t),
      lg: AppSpacing.lerpDouble(lg, other.lg, t),
    );
  }
}

/// The single default theme Steeped ships with until Milestone 3 adds
/// selectable skins.
ThemeData buildDefaultTheme() {
  const seedColor = Color(0xFF6F4E37); // coffee brown, nods to the app's name
  final colorScheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: Brightness.dark,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.surface,
    extensions: const [AppSpacing(), AppRadii()],
  );
}
