import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/logging/log_repository.dart';
import '../../core/storage/app_database.dart';

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
        title: const Text('Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear logs',
            onPressed: () => ref.read(logRepositoryProvider).clear(),
          ),
        ],
      ),
      body: logsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load: $error')),
        data: (logs) {
          if (logs.isEmpty) {
            return const Center(child: Text('No log entries yet.'));
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
                subtitle: Text(
                  '${entry.tag} · ${DateFormat.yMd().add_Hms().format(entry.timestamp)}',
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
