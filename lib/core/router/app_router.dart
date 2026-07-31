import 'package:go_router/go_router.dart';

import '../../features/auth/connect_server_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/library/home_shell_screen.dart';
import '../../features/settings/settings_screen.dart';
import 'splash_screen.dart';

/// Placeholder route graph (PLAN.md Phase 1.4). Auth-gated redirects are
/// wired up once Phase 3 has real session state to check.
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(
      path: '/connect-server',
      builder: (context, state) => const ConnectServerScreen(),
    ),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/home', builder: (context, state) => const HomeShellScreen()),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);
