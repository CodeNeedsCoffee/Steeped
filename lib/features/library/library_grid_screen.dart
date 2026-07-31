import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/cover_image_url.dart';
import '../../models/library_item.dart';
import '../../widgets/cover_image.dart';
import '../auth/state/session_controller.dart';
import '../auth/state/session_state.dart';
import 'state/library_providers.dart';

/// PLAN.md Phase 4.4: full library view. Single default-theme grid — the
/// shelf-of-spines-vs-modern-grid skin divergence is Milestone 3. Filtering
/// & sorting (4.6) and search (4.7) are deferred; server default order only.
class LibraryGridScreen extends ConsumerStatefulWidget {
  const LibraryGridScreen({required this.libraryId, super.key});

  final String libraryId;

  @override
  ConsumerState<LibraryGridScreen> createState() => _LibraryGridScreenState();
}

class _LibraryGridScreenState extends ConsumerState<LibraryGridScreen> {
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
    final (serverUrl, token) = switch (session) {
      SessionAuthenticated(:final serverUrl, :final user) => (
        serverUrl,
        user.effectiveToken,
      ),
      _ => (null, null),
    };

    return Scaffold(
      appBar: AppBar(title: Text('Library (${state.total})')),
      body: state.items.isEmpty && state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null && state.items.isEmpty
          ? Center(child: Text('Failed to load: ${state.error}'))
          : serverUrl == null
          ? const SizedBox.shrink()
          : GridView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
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
                return _GridTile(item: item, serverUrl: serverUrl, token: token);
              },
            ),
    );
  }
}

class _GridTile extends StatelessWidget {
  const _GridTile({required this.item, required this.serverUrl, required this.token});

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
