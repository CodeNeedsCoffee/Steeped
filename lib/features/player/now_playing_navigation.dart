import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Whether `/now-playing` is currently part of the navigation stack.
///
/// Set eagerly (synchronously, before the push below) when opened — that's
/// what guards [openNowPlaying] against firing twice in quick succession
/// (e.g. a Play button's post-load auto-open racing the user manually
/// tapping the mini-player while that load was still in flight, which used
/// to stack two instances of the same screen needing two pops to leave):
/// `GoRouter.push` is async, so without setting this ahead of the push
/// landing, a second trigger in that same window would see "not open yet"
/// and push a second instance.
///
/// Cleared the opposite way: not by hand, but by `appRouterProvider`'s
/// listener keeping this in sync with the router's actual
/// `currentConfiguration` (bug fix 2026-10-01, reported by evan: mini-
/// player permanently stuck, tapping it did nothing, nothing in the logs).
/// The old version cleared this only via a `whenComplete` on the push's
/// Future, which resolves solely on a *pop* — but `AppRouter`'s `redirect`
/// re-runs on every session change, and a forced logout while
/// `/now-playing` was open sent the router to `/connect-server` via a
/// stack-*replacing* navigation, never a pop, stranding that Future
/// forever and leaving this guard stuck `true` for the rest of the app
/// process. Deriving it from the router's real state instead means it's
/// correct no matter how the route leaves the stack.
final nowPlayingOpenProvider = StateProvider<bool>((ref) => false);

void openNowPlaying(BuildContext context, WidgetRef ref) {
  if (ref.read(nowPlayingOpenProvider)) return;
  ref.read(nowPlayingOpenProvider.notifier).state = true;
  context.push('/now-playing');
}
