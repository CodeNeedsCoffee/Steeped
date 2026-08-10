import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/theme/app_skin_style.dart';

/// PLAN.md Phase 2.2: real frosted-glass backdrop blur (`BackdropFilter` +
/// `ImageFilter.blur`), applied only when the active skin's
/// [AppSkinStyle.useFrostedSurfaces] is true. A plain passthrough
/// otherwise — Bookshelf wants opaque wood-toned surfaces, not a blur, so
/// callers don't need their own skin branching to use this everywhere a
/// surface should frost when glass-modern is active.
class GlassSurface extends StatelessWidget {
  const GlassSurface({required this.child, this.color, super.key});

  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).extension<AppSkinStyle>();
    if (style == null || !style.useFrostedSurfaces || style.blurSigma <= 0) {
      return child;
    }
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: style.blurSigma,
          sigmaY: style.blurSigma,
        ),
        child: Container(
          color:
              color ??
              Theme.of(context).colorScheme.surface.withValues(alpha: 0.55),
          child: child,
        ),
      ),
    );
  }
}
