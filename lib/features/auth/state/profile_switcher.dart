import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/app_database.dart';
import '../../../l10n/l10n.dart';
import '../../downloads/state/download_controller.dart';
import '../../library/state/library_providers.dart';
import '../../player/state/playback_controller.dart';
import '../../settings/data/app_settings.dart';
import '../../settings/state/settings_providers.dart';
import '../data/server_profile_repository.dart';
import 'session_controller.dart';
import 'session_state.dart';

/// QOL_PLAN E2.3: switching between saved servers/accounts.
///
/// [SessionController] owns *who is signed in*. This owns the
/// housekeeping around a switch that touches other features: stopping
/// playback (its final progress sync still goes to the account that was
/// playing) and resetting per-account UI state.
class ProfileSwitcher {
  ProfileSwitcher(this._ref);

  final Ref _ref;

  /// Stops playback and clears state that only makes sense for the account
  /// being left. Safe to call when nothing is playing.
  Future<void> prepareForChange() async {
    await _ref.read(playbackControllerProvider.notifier).closePlayer();
    _ref.read(playQueueProvider.notifier).state = null;
    _ref.read(selectedLibraryIdProvider.notifier).state = null;
  }

  Future<void> switchTo(String profileId) async {
    await prepareForChange();
    await _ref.read(sessionControllerProvider.notifier).switchTo(profileId);
  }

  /// Removes a saved account. [deleteDownloads] also deletes the files that
  /// came from it; otherwise they stay on the device, still playable.
  Future<void> removeProfile(
    String profileId, {
    required bool deleteDownloads,
  }) async {
    final session = _ref.read(sessionControllerProvider);
    final active = session is SessionAuthenticated
        ? session.profileId
        : null;
    if (profileId == active) await prepareForChange();
    if (deleteDownloads) {
      await _ref
          .read(downloadRepositoryProvider)
          .deleteDownloadsForProfile(profileId);
    }
    await _ref.read(sessionControllerProvider.notifier).removeProfile(profileId);
  }
}

final profileSwitcherProvider = Provider<ProfileSwitcher>(
  (ref) => ProfileSwitcher(ref),
);

/// Whether something is loaded in the player right now.
bool _isPlaying(WidgetRef ref) =>
    ref.read(currentPlaybackItemProvider) != null &&
    (ref.read(isPlayingProvider).valueOrNull ?? false);

/// Switches account, first confirming when audio is playing (unless the
/// user turned that prompt off). Returns true if the switch happened.
Future<bool> confirmAndSwitchProfile(
  BuildContext context,
  WidgetRef ref,
  ServerProfile target,
) async {
  final settings =
      ref.read(appSettingsProvider).valueOrNull ?? const AppSettings();
  if (settings.confirmSwitchWhilePlaying && _isPlaying(ref)) {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.switchAccountTitle),
        content: Text(ctx.l10n.switchAccountWhilePlaying(_hostOf(target.serverUrl))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.l10n.switchAction),
          ),
        ],
      ),
    );
    if (ok != true) return false;
  }
  await ref.read(profileSwitcherProvider).switchTo(target.id);
  return true;
}

/// Asks what to do with the account's downloads, then removes it. Returns
/// true if the account was removed.
Future<bool> confirmAndRemoveProfile(
  BuildContext context,
  WidgetRef ref,
  ServerProfile profile,
) async {
  // true = delete downloads too, false = keep them, null = cancelled.
  final choice = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(ctx.l10n.removeAccountTitle(profile.username)),
      content: Text(ctx.l10n.removeAccountMessage(_hostOf(profile.serverUrl))),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(ctx.l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(ctx.l10n.removeAndDeleteDownloads),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(ctx.l10n.removeKeepDownloads),
        ),
      ],
    ),
  );
  if (choice == null) return false;
  await ref
      .read(profileSwitcherProvider)
      .removeProfile(profile.id, deleteDownloads: choice);
  return true;
}

/// "audiobooks.example.com" from "https://audiobooks.example.com:8443/abs".
String hostOfServerUrl(String serverUrl) => _hostOf(serverUrl);

String _hostOf(String serverUrl) {
  final uri = Uri.tryParse(serverUrl);
  if (uri == null || uri.host.isEmpty) return serverUrl;
  return uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
}
