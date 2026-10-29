import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/skin.dart';
import '../../core/theme/skin_registry.dart';
import 'data/app_settings.dart';
import 'state/settings_providers.dart';
import '../../l10n/l10n.dart';
import '../../l10n/enum_labels.dart';

/// PLAN.md Phase 2.6: switch skins live — tapping a skin applies it
/// immediately (this whole screen re-themes along with everything else,
/// since [AppSettings.skinId] flows straight into `MaterialApp.theme` in
/// `app.dart`), so there's no separate "preview" step to build — the
/// switch itself *is* the preview.
class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings =
        ref.watch(appSettingsProvider).valueOrNull ?? const AppSettings();
    final controller = ref.read(appSettingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.appearance)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(context.l10n.theme, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<ThemeVariant>(
            showSelectedIcon: false,
            segments: [
              for (final v in ThemeVariant.values)
                ButtonSegment(
                  value: v,
                  label: Text(
                    v == ThemeVariant.system
                        ? context.l10n.themeSystemShort
                        : v.localized(context.l10n),
                  ),
                ),
            ],
            selected: {ThemeVariant.parse(settings.themeVariant)},
            onSelectionChanged: (s) =>
                controller.save(settings.copyWith(themeVariant: s.first.name)),
          ),
          const SizedBox(height: 20),
          Text(context.l10n.skin, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final skin in availableSkins) ...[
            _SkinCard(
              skin: skin,
              variant: ThemeVariant.parse(
                settings.themeVariant,
              ).resolve(MediaQuery.platformBrightnessOf(context)),
              selected: skin.id.name == settings.skinId,
              onTap: () =>
                  controller.save(settings.copyWith(skinId: skin.id.name)),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _SkinCard extends StatelessWidget {
  const _SkinCard({
    required this.skin,
    required this.variant,
    required this.selected,
    required this.onTap,
  });

  final Skin skin;
  final ThemeVariant variant;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Preview swatches use the *skin's own* theme colors, not the current
    // app theme — so evan can see what a skin looks like before it's
    // active, not just after switching to it.
    final previewScheme = skin.buildTheme(variant).colorScheme;

    return Semantics(
      button: true,
      selected: selected,
      label: selected
          ? context.l10n.skinSelectedSuffix(skin.id.localized(context.l10n))
          : skin.id.localized(context.l10n),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _SkinSwatch(scheme: previewScheme),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        skin.id.localized(context.l10n),
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        skin.id.description(context.l10n),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SkinSwatch extends StatelessWidget {
  const _SkinSwatch({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.3)),
      ),
      child: Center(
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: scheme.primary,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
