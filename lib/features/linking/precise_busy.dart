import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';

/// True while Precise is listening to the audio to find the reader's place.
final preciseBusyProvider = StateProvider<bool>((ref) => false);

/// Puts a "Finding your place..." card with a spinner in the middle of
/// [child] (and blocks taps) while [preciseBusyProvider] is set.
class PreciseBusyOverlay extends ConsumerWidget {
  const PreciseBusyOverlay({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(preciseBusyProvider);
    return Stack(
      children: [
        child,
        if (busy) ...[
          const Positioned.fill(
            child: ModalBarrier(color: Colors.black54, dismissible: false),
          ),
          Positioned.fill(
            child: Center(
              // Frosted glass: the page behind is blurred so the text on the
              // card stays readable, with a tint and a hairline edge.
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _tint(Theme.of(context).colorScheme),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 30,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 48,
                            height: 48,
                            child: CircularProgressIndicator(strokeWidth: 5),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            context.l10n.preciseFinding,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.none,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// The glass tint: the surface colour at about 60%, enough to read against while
// the blurred page still shows through.
Color _tint(ColorScheme cs) => cs.surface.withAlpha(255).withValues(alpha: 0.6);
