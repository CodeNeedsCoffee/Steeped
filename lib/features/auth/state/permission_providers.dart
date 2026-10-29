import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'session_controller.dart';
import 'session_state.dart';

/// Whether the signed-in user may download. Defaults to true when there is
/// no session (e.g. offline bootstrap) so downloaded content stays usable.
final canDownloadProvider = Provider<bool>((ref) {
  final session = ref.watch(sessionControllerProvider);
  if (session is SessionAuthenticated) return session.user.canDownload;
  return true;
});
