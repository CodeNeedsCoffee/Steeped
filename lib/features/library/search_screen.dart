import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/cover_image_url.dart';
import '../../models/library_item.dart';
import '../../models/library_query.dart';
import '../../models/library_series.dart';
import '../../models/search_results.dart';
import 'library_actions.dart';
import 'library_browse_widgets.dart';
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
            hintText: 'Search books, series, authors…',
            border: InputBorder.none,
          ),
          onChanged: (query) {
            setState(() {});
            ref
                .read(searchControllerProvider(widget.libraryId).notifier)
                .search(query);
          },
          onSubmitted: (q) => ref.read(recentSearchesProvider.notifier).add(q),
        ),
      ),
      body: serverUrl == null
          ? const SizedBox.shrink()
          : resultsAsync.when(
              data: (results) {
                if (results == null) {
                  return _RecentSearches(
                    onPick: (term) {
                      _controller.text = term;
                      setState(() {});
                      ref
                          .read(searchControllerProvider(widget.libraryId).notifier)
                          .search(term);
                    },
                  );
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
                    if (results.authors.isNotEmpty)
                      _ResultSection(
                        title: 'Authors',
                        children: [
                          for (final a in results.authors)
                            ListTile(
                              leading: AuthorAvatar(
                                author: a,
                                serverUrl: serverUrl,
                                token: token,
                                size: 40,
                              ),
                              title: Text(a.name),
                              subtitle: Text('${a.numBooks} books'),
                              onTap: () {
                                ref.read(recentSearchesProvider.notifier).add(_controller.text);
                                context.push('/author/${a.id}');
                              },
                            ),
                        ],
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
                    ..._facetSection(context, 'Narrators', LibraryFilterGroup.narrators, results.narrators),
                    ..._facetSection(context, 'Genres', LibraryFilterGroup.genres, results.genres),
                    ..._facetSection(context, 'Tags', LibraryFilterGroup.tags, results.tags),
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

extension on _SearchScreenState {
  List<Widget> _facetSection(
    BuildContext context,
    String title,
    LibraryFilterGroup group,
    List<SearchFacet> facets,
  ) {
    if (facets.isEmpty) return const [];
    return [
      _ResultSection(
        title: title,
        children: [
          for (final f in facets)
            ListTile(
              leading: const Icon(Icons.filter_alt_outlined),
              title: Text(f.name),
              subtitle: Text('${f.count} items'),
              onTap: () {
                ref.read(recentSearchesProvider.notifier).add(_controller.text);
                final q = ref.read(libraryQueryProvider(widget.libraryId));
                ref
                    .read(libraryQueryProvider(widget.libraryId).notifier)
                    .update(q.withFilter(group, f.name));
                context.push('/library/${widget.libraryId}');
              },
            ),
        ],
      ),
    ];
  }
}

class _RecentSearches extends ConsumerWidget {
  const _RecentSearches({required this.onPick});

  final void Function(String) onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentSearchesProvider);
    if (recent.isEmpty) {
      return const Center(child: Text('Search this library.'));
    }
    return ListView(
      children: [
        ListTile(
          title: const Text('Recent searches'),
          trailing: TextButton(
            onPressed: () => ref.read(recentSearchesProvider.notifier).clear(),
            child: const Text('Clear'),
          ),
        ),
        for (final term in recent)
          ListTile(
            leading: const Icon(Icons.history),
            title: Text(term),
            onTap: () => onPick(term),
          ),
      ],
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

class _BookResultTile extends ConsumerWidget {
  const _BookResultTile({required this.item, required this.serverUrl, required this.token});

  final LibraryItem item;
  final String serverUrl;
  final String? token;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      onLongPress: () => showItemQuickActions(context, ref, item),
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
