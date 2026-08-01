import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/skin.dart';
import '../../core/theme/skin_registry.dart';
import 'data/app_settings.dart';
import 'state/settings_providers.dart';

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
      appBar: AppBar(title: const Text('Appearance')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: availableSkins.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final skin = availableSkins[index];
          final selected = skin.id.name == settings.skinId;
          return _SkinCard(
            skin: skin,
            selected: selected,
            onTap: () =>
                controller.save(settings.copyWith(skinId: skin.id.name)),
          );
        },
      ),
    );
  }
}

class _SkinCard extends StatelessWidget {
  const _SkinCard({
    required this.skin,
    required this.selected,
    required this.onTap,
  });

  final Skin skin;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Preview swatches use the *skin's own* theme colors, not the current
    // app theme — so evan can see what a skin looks like before it's
    // active, not just after switching to it.
    final previewScheme = skin.buildTheme().colorScheme;

    return Semantics(
      button: true,
      selected: selected,
      label: '${skin.displayName}${selected ? ', selected' : ''}',
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
                      Text(skin.displayName, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        skin.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
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
