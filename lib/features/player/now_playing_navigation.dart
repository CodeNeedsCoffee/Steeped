import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// True from the moment a `/now-playing` push is issued until that route is
/// popped. Guards [openNowPlaying] against firing twice in quick succession
/// — e.g. a Play button's post-load auto-open racing the user manually
/// tapping the mini-player while that load was still in flight — which used
/// to stack two instances of the same screen, needing two pops to leave.
final _nowPlayingOpenProvider = StateProvider<bool>((ref) => false);

void openNowPlaying(BuildContext context, WidgetRef ref) {
  if (ref.read(_nowPlayingOpenProvider)) return;
  ref.read(_nowPlayingOpenProvider.notifier).state = true;
  context.push('/now-playing').whenComplete(() {
    ref.read(_nowPlayingOpenProvider.notifier).state = false;
  });
}

/// Bug fix 2026-10-01 (reported by evan: mini-player permanently stuck —
/// tapping it did nothing, nothing in the logs). The guard above only
/// clears when `/now-playing` is *popped*. But `AppRouter`'s `redirect`
/// re-runs on every session change (`GoRouterRefreshNotifier`), and a
/// forced logout while `/now-playing` is open makes it redirect to
/// `/connect-server` — a stack-replacing navigation, not a pop. That
/// strands `context.push`'s Future unresolved, `whenComplete` never fires,
/// and the guard stays `true` for the rest of the app process, silently
/// no-opping every future tap. Call this wherever the session is known to
/// have left `SessionAuthenticated` so the guard can't outlive the route
/// it was tracking.
void resetNowPlayingOpenGuard(WidgetRef ref) {
  ref.read(_nowPlayingOpenProvider.notifier).state = false;
}
