import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/cover_image_url.dart';
import '../../core/theme/app_skin_style.dart';
import '../../models/library_item.dart';
import '../../models/library_query.dart';
import 'library_actions.dart';
import 'library_toolbar.dart';
import '../../widgets/cover_image.dart';
import '../auth/state/session_controller.dart';
import '../auth/state/session_state.dart';
import '../player/mini_player.dart';
import 'state/library_providers.dart';

/// Thin wrapper around [LibraryItemsGrid] for the standalone `/library/:id`
/// route (deep links, and anywhere still pushing to it directly). The grid
/// itself is a self-contained widget so PLAN.md Phase 4.10's Library tab can
/// embed it directly, without its own `Scaffold`/`AppBar`/`MiniPlayer`.
class LibraryGridScreen extends ConsumerWidget {
  const LibraryGridScreen({required this.libraryId, super.key});

  final String libraryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = ref.watch(libraryItemsProvider(libraryId)).total;
    return Scaffold(
      appBar: AppBar(title: Text('Library ($total)')),
      body: Column(
        children: [
          LibraryToolbar(libraryId: libraryId),
          Expanded(child: LibraryItemsGrid(libraryId: libraryId, topPadding: 4)),
        ],
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}

/// PLAN.md Phase 4.4/2.7/4.10: full library grid, with real skin divergence
/// — [CoverStyle.modernCard] (Glass Modern) is a plain rounded-cover grid;
/// [CoverStyle.bookSpine] (Bookshelf) adds spine-edge shading/shadow per
/// tile (see [_BookSpineFrame]) on top of that skin's already-warm,
/// opaque-card theme tokens. Filtering & sorting (4.6) are still deferred;
/// search (4.7) is now handled by [SearchScreen] rather than filtering this
/// grid in place; server default order only.
class LibraryItemsGrid extends ConsumerStatefulWidget {
  const LibraryItemsGrid({required this.libraryId, this.topPadding = 16, super.key});

  final String libraryId;

  /// Extra top padding, on top of the grid's own 16px margin, so this can
  /// be embedded under a transparent `extendBodyBehindAppBar` app bar (the
  /// Home shell's Library tab) without its first row hiding behind it.
  /// The standalone `/library/:id` route (opaque app bar) uses the default.
  final double topPadding;

  @override
  ConsumerState<LibraryItemsGrid> createState() => _LibraryItemsGridState();
}

class _LibraryItemsGridState extends ConsumerState<LibraryItemsGrid> {
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
      ref.read(libraryItemsProvider(widget.libraryId).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    final state = ref.watch(libraryItemsProvider(widget.libraryId));
    final viewMode = ref.watch(libraryQueryProvider(widget.libraryId)).viewMode;
    final (serverUrl, token) = switch (session) {
      SessionAuthenticated(:final serverUrl, :final user) => (
        serverUrl,
        user.effectiveToken,
      ),
      _ => (null, null),
    };

    if (state.items.isEmpty && state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.items.isEmpty) {
      return Center(child: Text('Failed to load: ${state.error}'));
    }
    if (state.items.isEmpty) {
      final filtered = ref.watch(libraryQueryProvider(widget.libraryId)).hasFilter;
      return Center(
        child: Text(filtered ? 'Nothing matches this filter.' : 'This library is empty.'),
      );
    }
    if (serverUrl == null) {
      return const SizedBox.shrink();
    }
    Future<void> refresh() => ref
        .read(libraryItemsProvider(widget.libraryId).notifier)
        .loadFirstPage();
    if (viewMode == LibraryViewMode.list) {
      return RefreshIndicator(
        onRefresh: refresh,
        child: ListView.builder(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(8, widget.topPadding, 8, 16),
          itemCount: state.items.length + (state.hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= state.items.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final item = state.items[index];
            return ListTile(
              leading: CoverImage(
                url: coverImageUrl(
                  serverUrl: serverUrl,
                  itemId: item.id,
                  token: token,
                  updatedAt: item.updatedAt,
                ),
                width: 48,
                height: 48,
              ),
              title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                [
                  ?item.authorOrPublisherName,
                  if (item.duration != null) _fmt(item.duration!),
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => context.push('/item/${item.id}'),
              onLongPress: () => showItemQuickActions(context, ref, item),
            );
          },
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: refresh,
      child: GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(16, widget.topPadding, 16, 16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.62,
      ),
      itemCount: state.items.length + (state.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= state.items.length) {
          return const Center(child: CircularProgressIndicator());
        }
        final item = state.items[index];
        return LibraryBookTile(item: item, serverUrl: serverUrl, token: token);
      },
    ),
    );
  }

  static String _fmt(double seconds) {
    final d = Duration(seconds: seconds.round());
    return d.inHours == 0
        ? '${d.inMinutes}m'
        : '${d.inHours}h ${d.inMinutes.remainder(60)}m';
  }
}

/// Cover tile shared by the library grid, author/collection screens; a long
/// press opens the quick-actions sheet (LIBRARY_PLAN.md L6).
class LibraryBookTile extends ConsumerWidget {
  const LibraryBookTile({
    required this.item,
    required this.serverUrl,
    required this.token,
    super.key,
  });

  final LibraryItem item;
  final String serverUrl;
  final String? token;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coverStyle =
        Theme.of(context).extension<AppSkinStyle>()?.coverStyle ??
        CoverStyle.modernCard;
    final cover = CoverImage(
      url: coverImageUrl(
        serverUrl: serverUrl,
        itemId: item.id,
        token: token,
        updatedAt: item.updatedAt,
      ),
      width: double.infinity,
      height: double.infinity,
    );

    return GestureDetector(
      onTap: () => context.push('/item/${item.id}'),
      onLongPress: () => showItemQuickActions(context, ref, item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: coverStyle == CoverStyle.bookSpine
                ? _BookSpineFrame(child: cover)
                : cover,
          ),
          const SizedBox(height: 6),
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (item.authorOrPublisherName != null)
            Text(
              item.authorOrPublisherName!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
        ],
      ),
    );
  }
}

/// PLAN.md Phase 2.3/2.7: gives a real book its cover art a spine-like
/// presence on the shelf — a bright highlight strip near the left (spine)
/// edge, a dark page-block shadow along the right edge, and a drop shadow
/// beneath, rather than just a flat rectangle. No literal wood/paper
/// texture image (no branding art exists yet, Phase 9.9) — this is
/// procedural shading layered over the real cover, not a placeholder.
class _BookSpineFrame extends StatelessWidget {
  const _BookSpineFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 6,
            offset: const Offset(3, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: Stack(
          fit: StackFit.expand,
          children: [
            child,
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 6,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.28),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 10,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.35),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
