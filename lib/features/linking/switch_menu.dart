import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/state/settings_providers.dart';

/// What the Listen / Read button should do.
enum SwitchChoice { switchOnly, both, showPlayer, hidePlayer }

/// Decides what a switch button does: the "When switching" setting answers
/// directly unless it is "ask" (or [forceAsk], from a long-press), in which
/// case a small menu drops from the button. Null means the menu was dismissed.
///
/// [bothLabel] is the second entry ("Listen while reading" / "Read along");
/// when [alreadyPlaying] the second entry becomes [showPlayerLabel], or
/// [hidePlayerLabel] while the player is already [playerShown], and no
/// setting short-cuts it, because there is nothing to start.
Future<SwitchChoice?> chooseSwitch(
  BuildContext context,
  WidgetRef ref, {
  required String switchLabel,
  required String bothLabel,
  String? showPlayerLabel,
  String? hidePlayerLabel,
  bool playerShown = false,
  bool alreadyPlaying = false,
  bool forceAsk = false,
}) async {
  final mode =
      ref.read(appSettingsProvider).valueOrNull?.linkSwitchMode ?? 'ask';
  if (!forceAsk && !alreadyPlaying) {
    if (mode == 'switch') return SwitchChoice.switchOnly;
    if (mode == 'both') return SwitchChoice.both;
  }
  final box = context.findRenderObject() as RenderBox;
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
  final rect = RelativeRect.fromRect(
    topLeft & box.size,
    Offset.zero & overlay.size,
  );
  return showMenu<SwitchChoice>(
    context: context,
    position: rect,
    items: [
      PopupMenuItem(value: SwitchChoice.switchOnly, child: Text(switchLabel)),
      if (alreadyPlaying && playerShown)
        PopupMenuItem(
          value: SwitchChoice.hidePlayer,
          child: Text(hidePlayerLabel ?? bothLabel),
        )
      else
        PopupMenuItem(
          value: alreadyPlaying ? SwitchChoice.showPlayer : SwitchChoice.both,
          child: Text(
            alreadyPlaying ? (showPlayerLabel ?? bothLabel) : bothLabel,
          ),
        ),
    ],
  );
}
