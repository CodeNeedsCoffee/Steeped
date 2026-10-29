import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/data/app_settings.dart';
import '../../features/settings/state/settings_providers.dart';
import '../../l10n/l10n.dart';
import '../router/root_navigator_key.dart';
import 'connectivity_service.dart';

enum CellularAction { stream, download }

enum CellularDecision { allow, block, prompt }

/// Pure decision for a cellular [policy]. [sessionAnswer] is what the user
/// already answered to this action's prompt this session (null = not asked).
CellularDecision decideCellular(
  CellularPolicy policy, {
  required bool onCellular,
  bool? sessionAnswer,
}) {
  if (!onCellular) return CellularDecision.allow;
  switch (policy) {
    case CellularPolicy.always:
      return CellularDecision.allow;
    case CellularPolicy.never:
      return CellularDecision.block;
    case CellularPolicy.ask:
      if (sessionAnswer == null) return CellularDecision.prompt;
      return sessionAnswer ? CellularDecision.allow : CellularDecision.block;
  }
}

/// Per-session memory of "Ask" answers, one per action. Cleared on app
/// restart (it's a plain in-memory provider).
final cellularSessionAnswersProvider = StateProvider<Map<CellularAction, bool>>(
  (ref) => const {},
);

/// Shows the confirm dialog; overridable in tests.
final cellularPromptProvider =
    Provider<Future<bool> Function(CellularAction)>((ref) {
      return (action) async {
        final context = rootNavigatorKey.currentContext;
        if (context == null) return false;
        final result = await showDialog<bool>(
          context: context,
          builder: (ctx) {
            final l10n = ctx.l10n;
            final isStream = action == CellularAction.stream;
            return AlertDialog(
              title: Text(
                isStream ? l10n.cellularStreamTitle : l10n.cellularDownloadTitle,
              ),
              content: Text(
                isStream ? l10n.cellularStreamBody : l10n.cellularDownloadBody,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(l10n.notNow),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(isStream ? l10n.streamAction : l10n.downloadAction),
                ),
              ],
            );
          },
        );
        return result ?? false;
      };
    });

/// Returns true when [action] must NOT proceed. Sets
/// [cellularBlockNoticeProvider] when blocked.
Future<bool> cellularBlocks(Ref ref, CellularAction action) async {
  final settings =
      ref.read(appSettingsProvider).valueOrNull ?? const AppSettings();
  final policy = action == CellularAction.stream
      ? settings.cellularStreaming
      : settings.cellularDownloads;
  if (policy == CellularPolicy.always) return false;
  final onCellular = countsAsCellular(
    await currentNetworkKind(ref.read(connectivityProvider)),
    treatMeteredAsCellular: settings.treatMeteredAsCellular,
  );
  final answers = ref.read(cellularSessionAnswersProvider);
  var decision = decideCellular(
    policy,
    onCellular: onCellular,
    sessionAnswer: answers[action],
  );
  if (decision == CellularDecision.prompt) {
    final ok = await ref.read(cellularPromptProvider)(action);
    ref.read(cellularSessionAnswersProvider.notifier).state = {
      ...answers,
      action: ok,
    };
    decision = ok ? CellularDecision.allow : CellularDecision.block;
  }
  if (decision == CellularDecision.allow) return false;
  ref.read(cellularBlockNoticeProvider.notifier).state = action;
  return true;
}
