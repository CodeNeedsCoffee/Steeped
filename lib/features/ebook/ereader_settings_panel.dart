import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/ereader_settings.dart';
import 'state/ebook_providers.dart';

/// Shared between the EPUB reader's in-context settings sheet and the main
/// Settings → Ereader section (PLAN.md Phase 9.3) — same global
/// [ereaderSettingsProvider], so a change made from either place applies
/// everywhere immediately.
class EreaderSettingsPanel extends ConsumerWidget {
  const EreaderSettingsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings =
        ref.watch(ereaderSettingsProvider).valueOrNull ?? const EreaderSettings();
    final controller = ref.read(ereaderSettingsProvider.notifier);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reading Settings', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Font'),
              const Spacer(),
              SegmentedButton<EreaderFontFamily>(
                segments: const [
                  ButtonSegment(
                    value: EreaderFontFamily.sans,
                    label: Text('Sans'),
                  ),
                  ButtonSegment(
                    value: EreaderFontFamily.serif,
                    label: Text('Serif'),
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
              const Text('Bold'),
              const Spacer(),
              Switch(
                value: settings.bold,
                onChanged: (v) => controller.save(settings.copyWith(bold: v)),
              ),
            ],
          ),
          const Text('Font size'),
          Slider(
            value: settings.fontScale,
            min: 0.7,
            max: 2.0,
            divisions: 13,
            label: settings.fontScale.toStringAsFixed(1),
            onChanged: (v) => controller.save(settings.copyWith(fontScale: v)),
          ),
          const Text('Line spacing'),
          Slider(
            value: settings.lineSpacing,
            min: 1.0,
            max: 2.2,
            divisions: 12,
            label: settings.lineSpacing.toStringAsFixed(1),
            onChanged: (v) =>
                controller.save(settings.copyWith(lineSpacing: v)),
          ),
          Row(
            children: [
              const Text('Theme'),
              const Spacer(),
              SegmentedButton<EreaderTheme>(
                segments: const [
                  ButtonSegment(value: EreaderTheme.light, label: Text('Light')),
                  ButtonSegment(value: EreaderTheme.dark, label: Text('Dark')),
                  ButtonSegment(value: EreaderTheme.black, label: Text('Black')),
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
