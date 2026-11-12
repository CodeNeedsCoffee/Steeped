import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/ereader_settings.dart';
import 'state/ebook_providers.dart';
import '../../l10n/l10n.dart';

/// Shared between the EPUB reader's in-context settings sheet and the main
/// Settings → Ereader section (PLAN.md Phase 9.3) — same global
/// [ereaderSettingsProvider], so a change made from either place applies
/// everywhere immediately.
/// Which reader opened the panel; narrows it to the controls that apply
/// (null = the main Settings screen, which shows everything).
enum EreaderFormat { epub, pdf, comic }

class EreaderSettingsPanel extends ConsumerWidget {
  const EreaderSettingsPanel({super.key, this.showTheme = true, this.format});

  final EreaderFormat? format;

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
          if (format == null || format == EreaderFormat.epub)
            _flowRow(
              context,
              context.l10n.epubReadingMode,
              settings.epubFlow,
              (f) => controller.save(settings.copyWith(epubFlow: f)),
            ),
          if (format == null || format == EreaderFormat.pdf)
            _flowRow(
              context,
              context.l10n.pdfReadingMode,
              settings.pdfFlow,
              (f) => controller.save(settings.copyWith(pdfFlow: f)),
            ),
          if (format == null || format == EreaderFormat.comic)
            _flowRow(
              context,
              context.l10n.comicReadingMode,
              settings.comicFlow,
              (f) => controller.save(settings.copyWith(comicFlow: f)),
            ),
          _switchRow(
            context.l10n.tapToTurnPages,
            settings.tapToTurn,
            (v) => controller.save(settings.copyWith(tapToTurn: v)),
          ),
          _switchRow(
            context.l10n.keepScreenOn,
            settings.keepScreenOn,
            (v) => controller.save(settings.copyWith(keepScreenOn: v)),
          ),
          Text(context.l10n.brightness),
          Slider(
            value: settings.brightness,
            min: 0.2,
            max: 1.0,
            onChanged: (v) => controller.save(settings.copyWith(brightness: v)),
          ),
          if (format == null || format == EreaderFormat.epub) ..._textControls(
            context,
            settings,
            controller,
          ),
          if (showTheme) _themeRow(context, settings, controller),
        ],
      ),
    );
  }

  Widget _switchRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }

  Widget _flowRow(
    BuildContext context,
    String label,
    ReadingFlow value,
    ValueChanged<ReadingFlow> onChanged,
  ) {
    return _SpreadWrap(
      children: [
        Text(label),
        SegmentedButton<ReadingFlow>(
          segments: [
            ButtonSegment(
              value: ReadingFlow.paged,
              label: Text(context.l10n.pagedMode),
            ),
            ButtonSegment(
              value: ReadingFlow.scroll,
              label: Text(context.l10n.scrollMode),
            ),
          ],
          selected: {value},
          onSelectionChanged: (s) => onChanged(s.first),
        ),
      ],
    );
  }

  List<Widget> _textControls(
    BuildContext context,
    EreaderSettings settings,
    EreaderSettingsController controller,
  ) {
    return [
          _SpreadWrap(
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
          _switchRow(
            context.l10n.justifyText,
            settings.justify,
            (v) => controller.save(settings.copyWith(justify: v)),
          ),
          Text(context.l10n.margins),
          Slider(
            value: settings.margin,
            min: 4,
            max: 48,
            divisions: 11,
            onChanged: (v) => controller.save(settings.copyWith(margin: v)),
          ),
    ];
  }

  Widget _themeRow(
    BuildContext context,
    EreaderSettings settings,
    EreaderSettingsController controller,
  ) {
    return _SpreadWrap(
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
    );
  }
}

/// A label and its control, with the control pushed to the right edge like a
/// switch. It still wraps to a second line when the label is long or the text
/// is large. (A bare `Wrap` shrinks to its content, so `spaceBetween` did
/// nothing.)
class _SpreadWrap extends StatelessWidget {
  const _SpreadWrap({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 16,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 8,
      children: children,
    ),
  );
}
