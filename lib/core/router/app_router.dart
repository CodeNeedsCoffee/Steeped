import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/connect_server_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/state/session_controller.dart';
import '../../features/auth/state/session_state.dart';
import '../../features/library/home_shell_screen.dart';
import '../../features/library/item_detail_screen.dart';
import '../../features/library/library_grid_screen.dart';
import '../../features/settings/settings_screen.dart';
import 'go_router_refresh_notifier.dart';
import 'splash_screen.dart';

/// PLAN.md Phase 1.4 (routes) + Phase 3 (real auth-gated redirects, added
/// once [SessionController] existed to check).
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: GoRouterRefreshNotifier(
      ref,
      sessionControllerProvider,
    ),
    redirect: (context, state) {
      final session = ref.read(sessionControllerProvider);
      final location = state.matchedLocation;

      switch (session) {
        case SessionBootstrapping():
          return location == '/' ? null : '/';
        case SessionUnauthenticated():
          if (location == '/connect-server' || location == '/login') {
            return null;
          }
          return '/connect-server';
        case SessionAuthenticated():
          if (location == '/' ||
              location == '/connect-server' ||
              location == '/login') {
            return '/home';
          }
          return null;
      }
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(
        path: '/connect-server',
        builder: (context, state) => const ConnectServerScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) =>
            LoginScreen(serverUrl: state.extra as String),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeShellScreen(),
      ),
      GoRoute(
        path: '/library/:libraryId',
        builder: (context, state) => LibraryGridScreen(
          libraryId: state.pathParameters['libraryId']!,
        ),
      ),
      GoRoute(
        path: '/item/:itemId',
        builder: (context, state) =>
            ItemDetailScreen(itemId: state.pathParameters['itemId']!),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});
