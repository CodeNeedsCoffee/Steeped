import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/cover_image_url.dart';
import '../../models/library_item.dart';
import '../../models/library_series.dart';
import '../../widgets/cover_image.dart';
import '../auth/state/session_controller.dart';
import '../auth/state/session_state.dart';
import 'state/library_providers.dart';

/// PLAN.md Phase 4.7 (partial: Books + Series). A plain routed screen
/// rather than Flutter's `SearchDelegate` -- this app's `AppBar`s already
/// carry custom frosted/skin styling (see `GlassSurface` in
/// `home_shell_screen.dart`) that `SearchDelegate` would override.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({required this.libraryId, super.key});

  final String libraryId;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(searchControllerProvider(widget.libraryId));
    final session = ref.watch(sessionControllerProvider);
    final (serverUrl, token) = switch (session) {
      SessionAuthenticated(:final serverUrl, :final user) => (
        serverUrl,
        user.effectiveToken,
      ),
      _ => (null, null),
    };

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search books and series…',
            border: InputBorder.none,
          ),
          onChanged: (query) => ref
              .read(searchControllerProvider(widget.libraryId).notifier)
              .search(query),
        ),
      ),
      body: serverUrl == null
          ? const SizedBox.shrink()
          : resultsAsync.when(
              data: (results) {
                if (results == null) {
                  return const Center(child: Text('Search this library.'));
                }
                if (results.isEmpty) {
                  return const Center(child: Text('No results.'));
                }
                return ListView(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  children: [
                    if (results.books.isNotEmpty)
                      _ResultSection(
                        title: 'Books',
                        children: results.books
                            .map(
                              (item) => _BookResultTile(
                                item: item,
                                serverUrl: serverUrl,
                                token: token,
                              ),
                            )
                            .toList(),
                      ),
                    if (results.series.isNotEmpty)
                      _ResultSection(
                        title: 'Series',
                        children: results.series
                            .map(
                              (series) => _SeriesResultTile(
                                series: series,
                                serverUrl: serverUrl,
                                token: token,
                              ),
                            )
                            .toList(),
                      ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('Search failed: $error')),
            ),
    );
  }
}

class _ResultSection extends StatelessWidget {
  const _ResultSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        ...children,
      ],
    );
  }
}

class _BookResultTile extends StatelessWidget {
  const _BookResultTile({required this.item, required this.serverUrl, required this.token});

  final LibraryItem item;
  final String serverUrl;
  final String? token;

  @override
  Widget build(BuildContext context) {
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
      subtitle: item.authorOrPublisherName == null
          ? null
          : Text(
              item.authorOrPublisherName!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      onTap: () => context.push('/item/${item.id}'),
    );
  }
}

class _SeriesResultTile extends StatelessWidget {
  const _SeriesResultTile({required this.series, required this.serverUrl, required this.token});

  final LibrarySeries series;
  final String serverUrl;
  final String? token;

  @override
  Widget build(BuildContext context) {
    final coverItem = series.coverItem;
    return ListTile(
      leading: coverItem == null
          ? const Icon(Icons.collections_bookmark_outlined)
          : CoverImage(
              url: coverImageUrl(
                serverUrl: serverUrl,
                itemId: coverItem.id,
                token: token,
                updatedAt: coverItem.updatedAt,
              ),
              width: 48,
              height: 48,
            ),
      title: Text(series.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${series.books.length} book${series.books.length == 1 ? '' : 's'}'),
      onTap: () => context.push('/series/${series.id}', extra: series),
    );
  }
}
