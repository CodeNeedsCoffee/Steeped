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
  String get displayName;
  String get description;
  ThemeData buildTheme();
}
