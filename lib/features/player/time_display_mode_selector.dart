import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/data/app_settings.dart';
import '../settings/state/settings_providers.dart';

enum _TimeDisplayMode { chapter, book }

/// PLAN.md Phase 5.5 follow-up: lets the listener choose whether Now
/// Playing's time row shows chapter-relative time, book-relative (whole
/// item) time, or both — shared between the main Settings screen and Now
/// Playing's own quick-access sheet, the same way [EreaderSettingsPanel] is
/// shared between Settings and the EPUB reader's in-context sheet.
///
/// `SegmentedButton`'s `multiSelectionEnabled` lets both be picked at once;
/// `emptySelectionAllowed` defaults to false, so the framework itself
/// refuses to let the last remaining selection be tapped off — backed up by
/// a defensive `if (s.isEmpty) return` below in case that ever changes.
class TimeDisplayModeSelector extends ConsumerWidget {
  const TimeDisplayModeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings =
        ref.watch(appSettingsProvider).valueOrNull ?? const AppSettings();
    final controller = ref.read(appSettingsProvider.notifier);
    final selected = {
      if (settings.showChapterTime) _TimeDisplayMode.chapter,
      if (settings.showBookTime) _TimeDisplayMode.book,
    };

    return SegmentedButton<_TimeDisplayMode>(
      multiSelectionEnabled: true,
      segments: const [
        ButtonSegment(
          value: _TimeDisplayMode.chapter,
          label: Text('Chapter'),
        ),
        ButtonSegment(value: _TimeDisplayMode.book, label: Text('Book')),
      ],
      selected: selected,
      onSelectionChanged: (s) {
        if (s.isEmpty) return;
        controller.save(
          settings.copyWith(
            showChapterTime: s.contains(_TimeDisplayMode.chapter),
            showBookTime: s.contains(_TimeDisplayMode.book),
          ),
        );
      },
    );
  }
}
