import 'package:flutter/material.dart';

/// PLAN.md Phase 2.4: identifies a skin for persistence (stored by `.name`
/// in [AppSettings]) and for the switcher UI.
enum SkinId { glassModern, bookshelf }

/// PLAN.md Phase 2.4: a `Skin` interface both themes implement, so the rest
/// of the app only ever depends on this abstraction, never on which
/// concrete skin is active.
abstract class Skin {
  const Skin();

  SkinId get id;

  /// [variant] must be a concrete look ([ThemeVariant.light], [dark] or
  /// [black]); `system` is resolved to one of those by the caller.
  ThemeData buildTheme([ThemeVariant variant = ThemeVariant.dark]);
}

/// QOL_PLAN F1: which brightness a skin renders in. [system] follows the
/// OS; the app resolves it to [light] or [dark] before building a theme.
enum ThemeVariant {
  system,
  light,
  dark,
  black;

  static ThemeVariant parse(Object? raw) =>
      values.asNameMap()[raw] ?? ThemeVariant.dark;

  /// Resolves [system] against the platform brightness.
  ThemeVariant resolve(Brightness platform) =>
      this == system ? (platform == Brightness.dark ? dark : light) : this;
}
