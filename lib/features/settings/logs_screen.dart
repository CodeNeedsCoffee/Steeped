import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/logging/log_repository.dart';
import '../../core/storage/app_database.dart';
import '../../l10n/l10n.dart';

/// PLAN.md Phase 9.6: a real, working debug log — not a stub screen. Reads
/// live from drift (persists across restarts), hooked into real failure
/// paths (session refresh, progress sync, downloads — see call sites of
/// [logRepositoryProvider]) so evan can see what actually went wrong on a
/// self-hosted connection without needing `adb logcat`.
class LogsScreen extends ConsumerWidget {
  const LogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(_logsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.logs),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: context.l10n.clearLogs,
            onPressed: () => ref.read(logRepositoryProvider).clear(),
          ),
        ],
      ),
      body: logsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(context.l10n.failedToLoad(error))),
        data: (logs) {
          if (logs.isEmpty) {
            return Center(child: Text(context.l10n.noLogEntriesYet));
          }
          return ListView.builder(
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final entry = logs[index];
              return ListTile(
                dense: true,
                leading: Icon(
                  switch (entry.level) {
                    'error' => Icons.error_outline,
                    'warning' => Icons.warning_amber_outlined,
                    _ => Icons.info_outline,
                  },
                  color: switch (entry.level) {
                    'error' => Colors.redAccent,
                    'warning' => Colors.amber,
                    _ => null,
                  },
                ),
                title: Text(entry.message),
                // Collapsed repeats would otherwise look like a single
                // occurrence, hiding that something failed in a loop.
                subtitle: Text(
                  entry.repeatCount > 1
                      ? context.l10n.logEntrySubtitleRepeated(
                          entry.tag,
                          DateFormat.yMd().add_Hms().format(entry.timestamp),
                          entry.repeatCount,
                        )
                      : context.l10n.logEntrySubtitle(
                          entry.tag,
                          DateFormat.yMd().add_Hms().format(entry.timestamp),
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

final _logsStreamProvider = StreamProvider.autoDispose<List<LogEntry>>((ref) {
  return ref.watch(logRepositoryProvider).watchLogs();
});
