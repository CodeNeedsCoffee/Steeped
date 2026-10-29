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
import 'state/library_providers.dart';
import '../../l10n/l10n.dart';

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

/// Opens a series from just its id (collapsed-series tiles, the item page,
/// "Go to series"), where no [LibrarySeries] with its books is on hand.
/// Books come from the library's series filter, the same call "download
/// series" uses.
class SeriesLoaderScreen extends ConsumerWidget {
  const SeriesLoaderScreen({
    required this.seriesId,
    required this.libraryId,
    required this.name,
    super.key,
  });

  final String seriesId;
  final String? libraryId;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lib = libraryId ?? ref.watch(selectedLibraryIdProvider);
    if (lib == null) {
      return Scaffold(
        appBar: AppBar(title: Text(name)),
        body: Center(child: Text(context.l10n.seriesUnavailable)),
      );
    }
    final async = ref.watch(seriesBooksProvider((lib, seriesId)));
    return async.when(
      data: (books) => SeriesDetailScreen(
        series: LibrarySeries(id: seriesId, name: name, books: books),
      ),
      loading: () => Scaffold(
        appBar: AppBar(title: Text(name)),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: Text(name)),
        body: Center(child: Text(context.l10n.failedToLoadSeries(e))),
      ),
    );
  }
}

/// Route location for a series opened without its books in hand.
String seriesLocation(String id, {String? libraryId, String? name}) =>
    Uri(
      path: '/series/$id',
      queryParameters: {'library': ?libraryId, 'name': ?name},
    ).toString();
