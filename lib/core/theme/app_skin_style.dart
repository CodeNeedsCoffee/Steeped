import 'package:flutter/material.dart';

/// PLAN.md Phase 2.7: how a cover renders differs by skin — a flat modern
/// card grid vs. a skeuomorphic book-spine look on a shelf.
enum CoverStyle { modernCard, bookSpine }

/// PLAN.md Phase 2.1/2.2: the token slot that actually makes glass-modern
/// look and behave differently from bookshelf, beyond just color — whether
/// surfaces are frosted (`BackdropFilter` blur, Phase 2.2) and how covers
/// render (Phase 2.7). Read via `Theme.of(context).extension<AppSkinStyle>()`
/// the same way [AppSpacing]/[AppRadii] already are.
@immutable
class AppSkinStyle extends ThemeExtension<AppSkinStyle> {
  const AppSkinStyle({
    required this.useFrostedSurfaces,
    required this.blurSigma,
    required this.coverStyle,
  });

  final bool useFrostedSurfaces;
  final double blurSigma;
  final CoverStyle coverStyle;

  @override
  AppSkinStyle copyWith({
    bool? useFrostedSurfaces,
    double? blurSigma,
    CoverStyle? coverStyle,
  }) {
    return AppSkinStyle(
      useFrostedSurfaces: useFrostedSurfaces ?? this.useFrostedSurfaces,
      blurSigma: blurSigma ?? this.blurSigma,
      coverStyle: coverStyle ?? this.coverStyle,
    );
  }

  // Skins are a hard switch, not an animated transition — no meaningful
  // halfway point between "frosted" and "not frosted", so snap at the
  // midpoint rather than interpolating fields that don't blend sensibly.
  @override
  AppSkinStyle lerp(ThemeExtension<AppSkinStyle>? other, double t) {
    if (other is! AppSkinStyle) return this;
    return t < 0.5 ? this : other;
  }
}
