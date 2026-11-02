import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/ereader_settings.dart';
import 'state/ebook_providers.dart';
import '../../l10n/l10n.dart';

/// Shared between the EPUB reader's in-context settings sheet and the main
/// Settings → Ereader section (PLAN.md Phase 9.3) — same global
/// [ereaderSettingsProvider], so a change made from either place applies
/// everywhere immediately.
class EreaderSettingsPanel extends ConsumerWidget {
  const EreaderSettingsPanel({super.key, this.showTheme = true});

  /// The main Settings screen leaves the theme to Appearance.
  final bool showTheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings =
        ref.watch(ereaderSettingsProvider).valueOrNull ??
        const EreaderSettings();
    final controller = ref.read(ereaderSettingsProvider.notifier);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.readingSettings,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 16,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 8,
            children: [
              Text(context.l10n.font),
              SegmentedButton<EreaderFontFamily>(
                segments: [
                  ButtonSegment(
                    value: EreaderFontFamily.sans,
                    label: Text(context.l10n.sans),
                  ),
                  ButtonSegment(
                    value: EreaderFontFamily.serif,
                    label: Text(context.l10n.serif),
                  ),
                ],
                selected: {settings.fontFamily},
                onSelectionChanged: (s) =>
                    controller.save(settings.copyWith(fontFamily: s.first)),
              ),
            ],
          ),
          Row(
            children: [
              Text(context.l10n.bold),
              const Spacer(),
              Switch(
                value: settings.bold,
                onChanged: (v) => controller.save(settings.copyWith(bold: v)),
              ),
            ],
          ),
          Text(context.l10n.fontSize),
          Slider(
            value: settings.fontScale,
            min: 0.7,
            max: 2.0,
            divisions: 13,
            label: settings.fontScale.toStringAsFixed(1),
            onChanged: (v) => controller.save(settings.copyWith(fontScale: v)),
          ),
          Text(context.l10n.lineSpacing),
          Slider(
            value: settings.lineSpacing,
            min: 1.0,
            max: 2.2,
            divisions: 12,
            label: settings.lineSpacing.toStringAsFixed(1),
            onChanged: (v) =>
                controller.save(settings.copyWith(lineSpacing: v)),
          ),
          if (showTheme)
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 8,
              children: [
                Text(context.l10n.theme),
                SegmentedButton<EreaderTheme>(
                  segments: [
                    ButtonSegment(
                      value: EreaderTheme.light,
                      label: Text(context.l10n.light),
                    ),
                    ButtonSegment(
                      value: EreaderTheme.dark,
                      label: Text(context.l10n.dark),
                    ),
                    ButtonSegment(
                      value: EreaderTheme.black,
                      label: Text(context.l10n.black),
                    ),
                  ],
                  selected: {settings.theme},
                  onSelectionChanged: (s) =>
                      controller.save(settings.copyWith(theme: s.first)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
