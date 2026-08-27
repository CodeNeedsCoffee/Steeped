import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/cover_image_url.dart';
import '../../core/network/socket_service.dart';
import '../../core/storage/app_database.dart';
import '../../models/library.dart';
import '../../models/library_item.dart';
import '../../models/library_series.dart';
import '../../models/personalized_shelf.dart';
import '../../widgets/cover_image.dart';
import '../auth/state/session_controller.dart';
import '../auth/state/session_state.dart';
import '../downloads/downloads_screen.dart';
import '../downloads/state/download_controller.dart';
import '../../widgets/glass_surface.dart';
import '../../widgets/playback_loading_badge.dart';
import '../player/mini_player.dart';
import '../player/state/pending_sync_controller.dart';
import '../player/state/playback_controller.dart';
import 'library_grid_screen.dart';
import 'state/library_providers.dart';

/// PLAN.md Phase 4.2 (libraries + switcher), 4.3 (personalized home
/// shelves, rendered generically by shelf type rather than hardcoding each
/// row — see PersonalizedShelf), and 4.10 (top-level [Home | Series |
/// Library] tabs — "Browse Full Library" promoted from a scroll-body
/// button to a first-class tab; podcast libraries have no series concept,
/// so they get [Home | Library] instead). Single default look per Phase
/// 1.8; the bookshelf-vs-grid skin divergence is Milestone 3.
class HomeShellScreen extends ConsumerWidget {
  const HomeShellScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    if (session is! SessionAuthenticated) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Activates the global background_downloader update listener (Phase
    // 6.1) — no UI here, just needs to be watched somewhere near app root.
    ref.watch(downloadControllerProvider);
    // PLAN.md Phase 6.7: activates the durable pending-progress-sync flush
    // listener (connectivity-regained + app-start) — same "just needs to be
    // watched somewhere" pattern as the line above.
    ref.watch(pendingSyncControllerProvider);

    final librariesAsync = ref.watch(librariesProvider);

    return librariesAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      // A "Retry" action here is a defensive safety net, not just for
      // the 2026-08-02 dioProvider race fixed above: `librariesProvider`
      // is a plain FutureProvider that caches whatever it first resolves
      // to, success or failure, and nothing else re-triggers it — any
      // transient failure (a real network blip, not just that race)
      // would otherwise leave a user stuck here until a full app
      // restart, with no way to just try again.
      // A no-connectivity cold start used to dead-end here, even though
      // downloaded books need no network to play at all. Falling back to the
      // cached library list rebuilds the real shell (picker, Offline badge,
      // mini-player) with the Home tab served from local downloads instead.
      // Only reachable on a cold start: `librariesProvider` caches its first
      // result, so a mid-session drop keeps whatever already loaded.
      error: (error, _) {
        final cachedAsync = ref.watch(cachedLibrariesProvider);
        return cachedAsync.when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (_, _) => _NoLibrariesFallback(error: error),
          data: (cachedLibraries) {
            // Never fetched successfully on this device, so there's no
            // library id or media type to build tabs from.
            if (cachedLibraries.isEmpty) {
              return _NoLibrariesFallback(error: error);
            }
            final libraryId =
                ref.watch(selectedLibraryIdProvider) ?? cachedLibraries.first.id;
            final selected = cachedLibraries.firstWhere(
              (l) => l.id == libraryId,
              orElse: () => cachedLibraries.first,
            );
            return _HomeShellTabs(
              key: ValueKey(libraryId),
              libraries: cachedLibraries,
              libraryId: libraryId,
              isPodcast: selected.isPodcastLibrary,
              serverUrl: session.serverUrl,
              token: session.user.effectiveToken,
              isOffline: true,
            );
          },
        );
      },
      data: (libraries) {
        if (libraries.isEmpty) {
          return const Scaffold(
            body: Center(child: Text('No libraries on this server.')),
          );
        }
        final libraryId =
            ref.watch(selectedLibraryIdProvider) ?? libraries.first.id;
        final selected = libraries.firstWhere(
          (l) => l.id == libraryId,
          orElse: () => libraries.first,
        );
        return _HomeShellTabs(
          key: ValueKey(libraryId),
          libraries: libraries,
          libraryId: libraryId,
          isPodcast: selected.isPodcastLibrary,
          serverUrl: session.serverUrl,
          token: session.user.effectiveToken,
        );
      },
    );
  }
}

/// Shown only when libraries can't be fetched *and* nothing was ever cached
/// (so there's no library to build a shell around). `/downloads` still works
/// with no connectivity at all, so it stays reachable from here.
class _NoLibrariesFallback extends ConsumerWidget {
  const _NoLibrariesFallback({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Failed to load libraries: $error'),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () => ref.invalidate(librariesProvider),
              child: const Text('Retry'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.push('/downloads'),
              child: const Text('View Downloads'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Owns the [DefaultTabController] for `[Home | Series | Library]` (or just
/// `[Home | Library]` for podcast libraries) — keyed by `libraryId` in the
/// parent so switching libraries (which can change `isPodcast` and
/// therefore the tab count) always rebuilds with a fresh controller rather
/// than risking an out-of-range tab index.
class _HomeShellTabs extends ConsumerWidget {
  const _HomeShellTabs({
    required super.key,
    required this.libraries,
    required this.libraryId,
    required this.isPodcast,
    required this.serverUrl,
    required this.token,
    this.isOffline = false,
  });

  final List<Library> libraries;
  final String libraryId;
  final bool isPodcast;
  final String serverUrl;
  final String? token;

  /// Built from cached libraries after a failed cold-start fetch: the shell
  /// is identical, but tabs needing live browsing data degrade instead.
  final bool isOffline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabs = [
      const Tab(text: 'Home'),
      if (!isPodcast) const Tab(text: 'Series'),
      const Tab(text: 'Library'),
    ];
    // Compensates for Scaffold.extendBodyBehindAppBar below — without this,
    // the Library tab's first grid row would render underneath the
    // (now body-overlapping) app bar + TabBar instead of just below it.
    final topInset =
        MediaQuery.paddingOf(context).top + kToolbarHeight + kTextTabBarHeight + 16;

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        // PLAN.md Phase 2.2: the shelves need to actually scroll *behind*
        // the app bar for the frosted blur below to have anything to blur
        // — see the matching top padding added in [_HomeTab].
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          flexibleSpace: const GlassSurface(child: SizedBox.expand()),
          title: libraries.length == 1
              ? Text(libraries.first.name)
              : _LibraryPicker(libraries: libraries, selectedId: libraryId),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: _ConnectionBadge(status: ref.watch(socketServiceProvider)),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Search',
              onPressed: () => context.push('/search/$libraryId'),
            ),
            IconButton(
              icon: const Icon(Icons.download_done_outlined),
              tooltip: 'Downloads',
              onPressed: () => context.push('/downloads'),
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Settings',
              onPressed: () => context.push('/settings'),
            ),
          ],
          bottom: TabBar(tabs: tabs),
        ),
        body: TabBarView(
          children: [
            _HomeTab(
              libraryId: libraryId,
              isPodcast: isPodcast,
              serverUrl: serverUrl,
              token: token,
              isOffline: isOffline,
            ),
            if (!isPodcast)
              isOffline
                  ? const _OfflineTabPlaceholder(label: 'Series')
                  : _SeriesTab(libraryId: libraryId),
            isOffline
                ? const _OfflineTabPlaceholder(label: 'Library')
                : LibraryItemsGrid(libraryId: libraryId, topPadding: topInset),
          ],
        ),
        bottomNavigationBar: const MiniPlayer(),
      ),
    );
  }
}

class _LibraryPicker extends ConsumerWidget {
  const _LibraryPicker({required this.libraries, required this.selectedId});

  final List<Library> libraries;
  final String selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = libraries.firstWhere((l) => l.id == selectedId);
    return PopupMenuButton<String>(
      initialValue: selectedId,
      onSelected: (id) => ref.read(selectedLibraryIdProvider.notifier).state = id,
      itemBuilder: (context) => libraries
          .map((l) => PopupMenuItem(value: l.id, child: Text(l.name)))
          .toList(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(selected.name, overflow: TextOverflow.ellipsis),
          ),
          const Icon(Icons.arrow_drop_down),
        ],
      ),
    );
  }
}

class _HomeTab extends ConsumerWidget {
  const _HomeTab({
    required this.libraryId,
    required this.isPodcast,
    required this.serverUrl,
    required this.token,
    this.isOffline = false,
  });

  final String libraryId;
  final bool isPodcast;
  final String serverUrl;
  final String? token;
  final bool isOffline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isOffline) return _OfflineHomeTab(libraryId: libraryId);
    final shelvesAsync = ref.watch(personalizedShelvesProvider(libraryId));

    // Scaffold.extendBodyBehindAppBar above already redefines
    // MediaQuery.padding.top for body descendants to be the app bar's own
    // total height (toolbar + TabBar) -- that's the mechanism SafeArea
    // relies on to clear an extended-behind app bar. Adding kToolbarHeight/
    // kTextTabBarHeight again here double-counted that height (found via a
    // real device screenshot + a Linux-target repaint-boundary capture
    // showing the identical oversized gap, then confirmed by printing the
    // actual MediaQuery value from inside this widget vs. from the
    // Scaffold's own context). Only the deliberate +16 breathing room is
    // this widget's own addition.
    final topInset = MediaQuery.paddingOf(context).top + 16;

    return RefreshIndicator(
      onRefresh: () => ref.refresh(personalizedShelvesProvider(libraryId).future),
      child: ListView(
        padding: EdgeInsets.fromLTRB(0, topInset, 0, 16),
        children: [
          // PLAN.md Phase 7.6: quick access to the newest episodes across a
          // podcast library.
          if (isPodcast) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                onPressed: () =>
                    context.push('/library/$libraryId/recent-episodes'),
                icon: const Icon(Icons.podcasts),
                label: const Text('Latest Episodes'),
              ),
            ),
            const SizedBox(height: 16),
          ],
          shelvesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Failed to load home shelves: $error'),
            ),
            data: (shelves) {
              final visible = shelves.where((s) => !s.isEmpty).toList();
              if (visible.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('Nothing to show yet.')),
                );
              }
              return Column(
                children: visible
                    .map(
                      (shelf) => _ShelfRow(
                        shelf: shelf,
                        serverUrl: serverUrl,
                        token: token,
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SeriesTab extends ConsumerStatefulWidget {
  const _SeriesTab({required this.libraryId});

  final String libraryId;

  @override
  ConsumerState<_SeriesTab> createState() => _SeriesTabState();
}

class _SeriesTabState extends ConsumerState<_SeriesTab> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_maybeLoadMore);
    _scrollController.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 400) {
      ref.read(librarySeriesProvider(widget.libraryId).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(librarySeriesProvider(widget.libraryId));
    final session = ref.watch(sessionControllerProvider);
    final (serverUrl, token) = switch (session) {
      SessionAuthenticated(:final serverUrl, :final user) => (
        serverUrl,
        user.effectiveToken,
      ),
      _ => (null, null),
    };

    // See the long comment in _HomeTab -- MediaQuery.padding.top here is
    // already adjusted by Scaffold.extendBodyBehindAppBar to include the
    // app bar's full height, so only +16 breathing room is added on top.
    final topInset = MediaQuery.paddingOf(context).top + 16;

    if (state.series.isEmpty && state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.series.isEmpty) {
      return Center(child: Text('Failed to load series: ${state.error}'));
    }
    if (state.series.isEmpty) {
      return const Center(child: Text('No series in this library.'));
    }
    if (serverUrl == null) return const SizedBox.shrink();

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(0, topInset, 0, 16),
      itemCount: state.series.length + (state.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= state.series.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return _SeriesRow(
          series: state.series[index],
          serverUrl: serverUrl,
          token: token,
        );
      },
    );
  }
}

class _ShelfRow extends StatelessWidget {
  const _ShelfRow({required this.shelf, required this.serverUrl, required this.token});

  final PersonalizedShelf shelf;
  final String serverUrl;
  final String? token;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(shelf.label, style: Theme.of(context).textTheme.titleMedium),
        ),
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: switch (shelf.type) {
              ShelfEntityType.item => shelf.items.length,
              ShelfEntityType.series => shelf.seriesEntries.length,
              ShelfEntityType.authors => shelf.authorEntries.length,
              ShelfEntityType.unknown => 0,
            },
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) => switch (shelf.type) {
              ShelfEntityType.item => _ItemCard(
                item: shelf.items[index],
                serverUrl: serverUrl,
                token: token,
              ),
              ShelfEntityType.series => _SeriesCard(
                series: shelf.seriesEntries[index],
                serverUrl: serverUrl,
                token: token,
                width: 120,
              ),
              ShelfEntityType.authors => _LabelCard(text: shelf.authorEntries[index]),
              ShelfEntityType.unknown => const SizedBox.shrink(),
            },
          ),
        ),
      ],
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, required this.serverUrl, required this.token});

  final LibraryItem item;
  final String serverUrl;
  final String? token;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/item/${item.id}'),
      child: SizedBox(
        width: 120,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ItemCover(item: item, serverUrl: serverUrl, token: token, size: 120),
            const SizedBox(height: 6),
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemCover extends StatelessWidget {
  const _ItemCover({
    required this.item,
    required this.serverUrl,
    required this.token,
    required this.size,
  });

  final LibraryItem item;
  final String serverUrl;
  final String? token;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CoverImage(
      url: coverImageUrl(
        serverUrl: serverUrl,
        itemId: item.id,
        token: token,
        updatedAt: item.updatedAt,
      ),
      width: size,
      height: size,
    );
  }
}

/// PLAN.md Phase 4.5 (partial: series covers). A series' cover is its first
/// book's cover — Audiobookshelf has no series-level cover endpoint — so
/// this reuses [CoverImage]/[coverImageUrl] exactly like [_ItemCover],
/// keyed off [LibrarySeries.coverItem]. Falls back to the old plain-text
/// [_LabelCard] only if a series entry somehow has no books at all.
class _SeriesCard extends StatelessWidget {
  const _SeriesCard({
    required this.series,
    required this.serverUrl,
    required this.token,
    required this.width,
  });

  final LibrarySeries series;
  final String serverUrl;
  final String? token;
  final double width;

  @override
  Widget build(BuildContext context) {
    final coverItem = series.coverItem;
    if (coverItem == null) {
      return _LabelCard(text: series.name);
    }
    return GestureDetector(
      onTap: () => context.push('/series/${series.id}', extra: series),
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: _ItemCover(
                item: coverItem,
                serverUrl: serverUrl,
                token: token,
                size: width == double.infinity ? double.infinity : width,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              series.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              '${series.books.length} book${series.books.length == 1 ? '' : 's'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// The dedicated Series tab's row style (distinct from [_SeriesCard], which
/// stays a single-cover tile for the Home tab's horizontal "Series" shelf).
/// Modeled on Audiobookshelf's own series list: one full-width row per
/// series with every book's cover shown in a horizontally-scrollable strip,
/// so the whole series is browsable without opening [SeriesDetailScreen] --
/// tapping the row (header or any cover) still opens it, same destination as
/// [_SeriesCard].
class _SeriesRow extends StatelessWidget {
  const _SeriesRow({
    required this.series,
    required this.serverUrl,
    required this.token,
  });

  final LibrarySeries series;
  final String serverUrl;
  final String? token;

  static const _coverSize = 130.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/series/${series.id}', extra: series),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              series.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              '${series.books.length} book${series.books.length == 1 ? '' : 's'}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            if (series.books.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: _coverSize,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: series.books.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) => _ItemCover(
                    item: series.books[index],
                    serverUrl: serverUrl,
                    token: token,
                    size: _coverSize,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LabelCard extends StatelessWidget {
  const _LabelCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(text, textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis),
    );
  }
}

/// The Home tab when the app started with no connectivity: the server's
/// personalized shelves are unreachable, so downloaded content stands in for
/// "Continue Listening" — the one shelf that still works entirely offline.
class _OfflineHomeTab extends ConsumerWidget {
  const _OfflineHomeTab({required this.libraryId});

  final String libraryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloads = ref.watch(offlineContinueListeningProvider(libraryId));
    final topInset = MediaQuery.paddingOf(context).top + 16;

    return RefreshIndicator(
      // Doubles as "try to get back online" — without it the only way out of
      // the offline shell would be restarting the app, since
      // `librariesProvider` caches its failure for the process lifetime.
      onRefresh: () async {
        ref.invalidate(librariesProvider);
        await ref.read(librariesProvider.future).catchError((_) => <Library>[]);
      },
      child: ListView(
        padding: EdgeInsets.fromLTRB(0, topInset, 0, 16),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.cloud_off, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Can't reach the server. Showing downloaded content.",
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                TextButton(
                  onPressed: () => ref.invalidate(librariesProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'Continue Listening',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (downloads.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('No downloaded content yet.')),
            )
          else
            ...downloads.map((item) => _OfflineDownloadTile(item: item)),
        ],
      ),
    );
  }
}

/// A downloaded item on the offline Home tab. Deliberately not built on
/// [_ItemCard]/[_ItemCover] — those resolve covers through [CoverImage] over
/// the network, while a downloaded cover is a local file, which is why
/// [DownloadsScreen] renders it with [DownloadedItemCover] instead.
class _OfflineDownloadTile extends ConsumerWidget {
  const _OfflineDownloadTile({required this.item});

  final DownloadedItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(playbackLoadingIdProvider) == item.itemId;
    return ListTile(
      enabled: !isLoading,
      leading: PlaybackLoadingBadge(
        isLoading: isLoading,
        child: DownloadedItemCover(coverLocalPath: item.coverLocalPath),
      ),
      title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: item.authorNames.isEmpty
          ? null
          : Text(
              item.authorNames,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      onTap: isLoading
          ? null
          : () async {
              await ref
                  .read(playbackControllerProvider.notifier)
                  .playItem(item.itemId);
              if (context.mounted &&
                  ref.read(currentPlaybackItemProvider)?.downloadId ==
                      item.itemId) {
                context.push('/now-playing');
              }
            },
    );
  }
}

/// Series and Library browsing both need live server data this fallback
/// deliberately doesn't cache, so offline they explain themselves rather
/// than rendering an empty grid.
class _OfflineTabPlaceholder extends ConsumerWidget {
  const _OfflineTabPlaceholder({required this.label});

  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 40),
          const SizedBox(height: 12),
          Text('$label browsing needs a connection.'),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => ref.invalidate(librariesProvider),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _ConnectionBadge extends StatelessWidget {
  const _ConnectionBadge({required this.status});

  final SocketConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      SocketConnectionStatus.authenticated => (Colors.greenAccent, 'Live'),
      SocketConnectionStatus.connected => (Colors.amber, 'Connecting'),
      SocketConnectionStatus.connecting => (Colors.amber, 'Connecting'),
      SocketConnectionStatus.authFailed => (Colors.redAccent, 'Auth failed'),
      SocketConnectionStatus.disconnected => (Colors.grey, 'Offline'),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 10, color: color),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
