import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bridges a Riverpod provider to go_router's `refreshListenable` so route
/// `redirect` callbacks re-run whenever [SessionController]'s state changes
/// (login, logout, or a background session-expiry).
class GoRouterRefreshNotifier extends ChangeNotifier {
  GoRouterRefreshNotifier(Ref ref, ProviderListenable<Object?> provider) {
    _subscription = ref.listen<Object?>(provider, (_, _) => notifyListeners());
  }

  late final ProviderSubscription<Object?> _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}
