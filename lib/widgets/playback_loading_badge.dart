import 'package:flutter/material.dart';

/// PLAN.md Phase 5.14: wraps a leading cover/icon with a small spinner
/// overlay while [isLoading] — used by every Play-triggering row/button so
/// tapping play always shows *some* feedback during the fetch-then-buffer
/// gap before audio is actually audible, instead of looking unresponsive.
class PlaybackLoadingBadge extends StatelessWidget {
  const PlaybackLoadingBadge({
    required this.isLoading,
    required this.child,
    super.key,
  });

  final bool isLoading;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!isLoading) return child;
    return Stack(
      alignment: Alignment.center,
      children: [
        Opacity(opacity: 0.3, child: child),
        const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ],
    );
  }
}
