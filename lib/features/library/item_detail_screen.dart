import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/cover_image_url.dart';
import '../../models/library_item_detail.dart';
import '../../widgets/cover_image.dart';
import '../auth/state/session_controller.dart';
import '../auth/state/session_state.dart';
import 'state/library_providers.dart';

/// PLAN.md Phase 4.8: item detail screen. "Play"/"Read"/"Download"/"Add to
/// Playlist" actions are stubs for now — real playback is Phase 5,
/// downloads are Milestone 2, playlists are deferred (see Phase 4.5 note).
class ItemDetailScreen extends ConsumerWidget {
  const ItemDetailScreen({required this.itemId, super.key});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    final detailAsync = ref.watch(itemDetailProvider(itemId));
    final (serverUrl, token) = switch (session) {
      SessionAuthenticated(:final serverUrl, :final user) => (
        serverUrl,
        user.effectiveToken,
      ),
      _ => (null, null),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('')),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load: $error')),
        data: (item) => serverUrl == null
            ? const SizedBox.shrink()
            : _ItemDetailBody(item: item, serverUrl: serverUrl, token: token),
      ),
    );
  }
}

class _ItemDetailBody extends StatelessWidget {
  const _ItemDetailBody({required this.item, required this.serverUrl, required this.token});

  final LibraryItemDetail item;
  final String serverUrl;
  final String? token;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: CoverImage(
            url: coverImageUrl(
              serverUrl: serverUrl,
              itemId: item.id,
              token: token,
              updatedAt: item.updatedAt,
            ),
            width: 200,
            height: 200,
          ),
        ),
        const SizedBox(height: 16),
        Text(item.title, style: textTheme.headlineSmall, textAlign: TextAlign.center),
        if (item.subtitle != null)
          Text(item.subtitle!, style: textTheme.titleSmall, textAlign: TextAlign.center),
        if (item.authors.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              item.authorNames,
              style: textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
        if (item.series.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              item.series.map((s) => s.label).join(', '),
              style: textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
        if (item.progress != null) ...[
          const SizedBox(height: 12),
          LinearProgressIndicator(value: item.progress!.progress),
          Text(
            item.progress!.isFinished
                ? 'Finished'
                : '${(item.progress!.progress * 100).round()}% complete',
            style: textTheme.labelSmall,
          ),
        ],
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: () => _showComingSoon(context, 'Playback'),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Play'),
            ),
            if (item.hasEbook) ...[
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => _showComingSoon(context, 'Reading'),
                icon: const Icon(Icons.menu_book),
                label: const Text('Read'),
              ),
            ],
          ],
        ),
        if (item.isPodcast) ...[
          const SizedBox(height: 20),
          const Text(
            'Full podcast/episode browsing arrives in Milestone 2 (Phase 7).',
            textAlign: TextAlign.center,
          ),
        ],
        if (item.genres.isNotEmpty) ...[
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: item.genres.map((g) => Chip(label: Text(g))).toList(),
          ),
        ],
        if (item.narrators.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Narrated by ${item.narrators.join(', ')}', textAlign: TextAlign.center),
        ],
        if (!item.isPodcast) ...[
          const SizedBox(height: 8),
          Text(
            [
              if (item.duration != null) _formatDuration(item.duration!),
              if (item.chapters.isNotEmpty) '${item.chapters.length} chapters',
              if (item.publishedYear != null) item.publishedYear!,
            ].join(' · '),
            textAlign: TextAlign.center,
            style: textTheme.bodySmall,
          ),
        ],
        if (item.description != null) ...[
          const SizedBox(height: 20),
          Text(item.description!, style: textTheme.bodyMedium),
        ],
      ],
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature is coming in a later phase.')),
    );
  }

  String _formatDuration(double seconds) {
    final totalMinutes = (seconds / 60).round();
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours == 0) return '${minutes}m';
    return '${hours}h ${minutes}m';
  }
}
