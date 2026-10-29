import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/data/app_settings.dart';
import '../settings/state/settings_providers.dart';

/// Server address text honouring `AppSettings.maskServerAddress`: shows
/// `https://••••` until tapped.
class MaskedServerAddress extends ConsumerStatefulWidget {
  const MaskedServerAddress(this.url, {this.style, this.textAlign, super.key});

  final String url;
  final TextStyle? style;
  final TextAlign? textAlign;

  static String mask(String url) {
    final scheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').firstMatch(url);
    return '${scheme?.group(0) ?? ''}••••';
  }

  @override
  ConsumerState<MaskedServerAddress> createState() =>
      _MaskedServerAddressState();
}

class _MaskedServerAddressState extends ConsumerState<MaskedServerAddress> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final masked =
        (ref.watch(appSettingsProvider).valueOrNull ?? const AppSettings())
            .maskServerAddress;
    final hide = masked && !_revealed;
    final text = Text(
      hide ? MaskedServerAddress.mask(widget.url) : widget.url,
      style: widget.style,
      textAlign: widget.textAlign,
    );
    if (!masked) return text;
    return GestureDetector(
      onTap: () => setState(() => _revealed = !_revealed),
      child: text,
    );
  }
}
