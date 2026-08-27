import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/cover_image_url.dart';
import '../../models/library_item.dart';
import '../../models/library_series.dart';
import '../../widgets/cover_image.dart';
import '../auth/state/session_controller.dart';
import '../auth/state/session_state.dart';
import '../player/mini_player.dart';

/// PLAN.md Phase 4.10: reached from a [LibrarySeries] tile (Home shelf or
/// the Series tab), which already holds every book in the series -- see
/// `GET /api/libraries/:id/series`'s `books[]`, confirmed live to embed
/// full item data, not just ids. No second network call needed; `series`
/// always arrives via the route's `extra` (no bare-`/series/:id` deep-link
/// fallback in this pass -- see PLAN.md 4.10 note).
class SeriesDetailScreen extends ConsumerWidget {
  const SeriesDetailScreen({required this.series, super.key});

  final LibrarySeries series;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    final (serverUrl, token) = switch (session) {
      SessionAuthenticated(:final serverUrl, :final user) => (
        serverUrl,
        user.effectiveToken,
      ),
      _ => (null, null),
    };

    return Scaffold(
      appBar: AppBar(title: Text(series.name)),
      body: serverUrl == null
          ? const SizedBox.shrink()
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 160,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.62,
              ),
              itemCount: series.books.length,
              itemBuilder: (context, index) => _SeriesBookTile(
                item: series.books[index],
                serverUrl: serverUrl,
                token: token,
              ),
            ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}

class _SeriesBookTile extends StatelessWidget {
  const _SeriesBookTile({required this.item, required this.serverUrl, required this.token});

  final LibraryItem item;
  final String serverUrl;
  final String? token;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/item/${item.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: CoverImage(
              url: coverImageUrl(
                serverUrl: serverUrl,
                itemId: item.id,
                token: token,
                updatedAt: item.updatedAt,
              ),
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
