import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/data/app_settings.dart';
import '../settings/state/settings_providers.dart';
import 'state/pending_sync_controller.dart';
import '../../l10n/l10n.dart';

/// QOL_PLAN C2: small badge shown while progress updates are queued and
/// haven't reached the server. Tap to retry now. Hidden when nothing is
/// pending or the setting is off.
class SyncFailedBadge extends ConsumerWidget {
  const SyncFailedBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final show =
        (ref.watch(appSettingsProvider).valueOrNull ?? const AppSettings())
            .showSyncIndicator;
    final count = ref.watch(pendingSyncCountProvider).valueOrNull ?? 0;
    if (!show || count == 0) return const SizedBox.shrink();
    return IconButton(
      visualDensity: VisualDensity.compact,
      icon: Badge(
        label: Text('$count'),
        child: const Icon(Icons.sync_problem_outlined),
      ),
      tooltip: context.l10n.syncWaitingTooltip(count),
      onPressed: () =>
          ref.read(pendingSyncControllerProvider.notifier).flushPending(),
    );
  }
}
