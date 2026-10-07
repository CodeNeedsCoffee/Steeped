import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/library_browse.dart';
import '../../models/library_item.dart';
import '../../models/library_series.dart';
import '../../widgets/cover_image.dart';
import '../../core/network/cover_image_url.dart';
import '../player/mini_player.dart';
import '../player/now_playing_navigation.dart';
import '../player/state/playback_controller.dart';
import 'library_actions.dart';
import 'library_browse_widgets.dart';
import 'library_grid_screen.dart';
import 'state/library_providers.dart';

Future<void> _playQueue(
  BuildContext context,
  WidgetRef ref,
  String name,
  List<PlaylistItem> items,
  int start,
) async {
  final playable = items.where((i) => i.episodeId == null).toList();
  if (playable.isEmpty) return;
  final startItem = items[start];
  final idx = playable.indexWhere((i) => i.downloadId == startItem.downloadId);
  await ref
      .read(playbackControllerProvider.notifier)
      .startQueue(PlayQueue(name: name, items: playable), idx < 0 ? 0 : idx);
  if (context.mounted) openNowPlaying(context, ref);
}

PlaylistItem _asQueueItem(LibraryItem b) => PlaylistItem(
  libraryItemId: b.id,
  episodeId: null,
  item: b,
  episodeTitle: null,
  duration: b.duration,
);

class AuthorDetailScreen extends ConsumerWidget {
  const AuthorDetailScreen({required this.authorId, super.key});

  final String authorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(authorDetailProvider(authorId));
    final auth = sessionAuth(ref);
    return Scaffold(
      appBar: AppBar(title: Text(async.valueOrNull?.name ?? 'Author')),
      body: auth == null
          ? const SizedBox.shrink()
          : async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Failed to load author: $e')),
              data: (a) => CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          AuthorAvatar(
                            author: a,
                            serverUrl: auth.serverUrl,
                            token: auth.token,
                          ),
                          if (a.description != null &&
                              a.description!.trim().isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              a.description!,
                              maxLines: 6,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          if (a.series.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              children: [
                                for (final LibrarySeries s in a.series)
                                  ActionChip(
                                    label: Text(s.name),
                                    onPressed: () =>
                                        context.push('/series/${s.id}', extra: s),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    sliver: SliverGrid.builder(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 160,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 0.62,
                          ),
                      itemCount: a.books.length,
                      itemBuilder: (context, i) => LibraryBookTile(
                        item: a.books[i],
                        serverUrl: auth.serverUrl,
                        token: auth.token,
                      ),
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}

class CollectionDetailScreen extends ConsumerWidget {
  const CollectionDetailScreen({required this.collectionId, super.key});

  final String collectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(collectionDetailProvider(collectionId));
    final auth = sessionAuth(ref);
    final canEdit = canEditCollections(ref);
    final c = async.valueOrNull;
    final repo = ref.read(libraryRepositoryProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(c?.name ?? 'Collection'),
        actions: [
          if (c != null && canEdit)
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'rename') {
                  final name = await promptForName(
                    context,
                    title: 'Rename collection',
                    initial: c.name,
                  );
                  if (name == null) return;
                  await repo.updateCollection(c.id, name: name);
                  ref.invalidate(collectionDetailProvider(c.id));
                  ref.invalidate(collectionsProvider(c.libraryId));
                } else if (v == 'delete') {
                  final ok = await confirmAction(
                    context,
                    title: 'Delete collection?',
                    message: '"${c.name}" will be deleted for everyone on this server.',
                  );
                  if (!ok) return;
                  await repo.deleteCollection(c.id);
                  ref.invalidate(collectionsProvider(c.libraryId));
                  if (context.mounted) context.pop();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'rename', child: Text('Rename')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
        ],
      ),
      body: auth == null
          ? const SizedBox.shrink()
          : async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Failed to load collection: $e')),
              data: (c) => Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${c.books.length} books · ${formatDuration(c.totalDuration)}',
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: c.books.isEmpty
                              ? null
                              : () => _playQueue(context, ref, c.name,
                                  [for (final b in c.books) _asQueueItem(b)], 0),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Play all'),
                        ),
                        IconButton(
                          tooltip: 'Download all',
                          icon: const Icon(Icons.download_outlined),
                          onPressed: () async {
                            final n = await downloadBooks(
                              context,
                              ref,
                              c.books.map((b) => b.id),
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Queued $n downloads')),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: c.books.isEmpty
                        ? const Center(child: Text('This collection is empty.'))
                        : ListView(
                            children: [
                              for (final b in c.books)
                                ListTile(
                                  leading: CoverImage(
                                    url: coverImageUrl(
                                      serverUrl: auth.serverUrl,
                                      itemId: b.id,
                                      token: auth.token,
                                      updatedAt: b.updatedAt,
                                    ),
                                    width: 48,
                                    height: 48,
                                  ),
                                  title: Text(b.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  subtitle: Text(b.authorOrPublisherName ?? ''),
                                  onTap: () => context.push('/item/${b.id}'),
                                  onLongPress: () => showItemQuickActions(context, ref, b),
                                  trailing: canEdit
                                      ? IconButton(
                                          tooltip: 'Remove from collection',
                                          icon: const Icon(Icons.remove_circle_outline),
                                          onPressed: () async {
                                            await repo.removeBookFromCollection(c.id, b.id);
                                            ref.invalidate(collectionDetailProvider(c.id));
                                            ref.invalidate(collectionsProvider(c.libraryId));
                                          },
                                        )
                                      : null,
                                ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}

class PlaylistDetailScreen extends ConsumerStatefulWidget {
  const PlaylistDetailScreen({required this.playlistId, super.key});

  final String playlistId;

  @override
  ConsumerState<PlaylistDetailScreen> createState() =>
      _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends ConsumerState<PlaylistDetailScreen> {
  List<PlaylistItem>? _local; // optimistic order while a PATCH is in flight

  Future<void> _reorder(Playlist p, int oldIndex, int newIndex) async {
    final items = [...(_local ?? p.items)];
    if (newIndex > oldIndex) newIndex -= 1;
    items.insert(newIndex, items.removeAt(oldIndex));
    setState(() => _local = items);
    try {
      await ref.read(libraryRepositoryProvider).reorderPlaylist(p.id, items);
      ref.invalidate(playlistDetailProvider(p.id));
      ref.invalidate(playlistsProvider(p.libraryId));
    } catch (e) {
      if (mounted) {
        setState(() => _local = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not reorder: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(playlistDetailProvider(widget.playlistId));
    final auth = sessionAuth(ref);
    final repo = ref.read(libraryRepositoryProvider);
    final p = async.valueOrNull;
    ref.listen(playlistDetailProvider(widget.playlistId), (_, next) {
      if (next.hasValue) setState(() => _local = null);
    });
    return Scaffold(
      appBar: AppBar(
        title: Text(p?.name ?? 'Playlist'),
        actions: [
          if (p != null)
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'rename') {
                  final name = await promptForName(
                    context,
                    title: 'Rename playlist',
                    initial: p.name,
                  );
                  if (name == null) return;
                  await repo.renamePlaylist(p.id, name);
                  ref.invalidate(playlistDetailProvider(p.id));
                  ref.invalidate(playlistsProvider(p.libraryId));
                } else if (v == 'delete') {
                  final ok = await confirmAction(
                    context,
                    title: 'Delete playlist?',
                    message: '"${p.name}" will be deleted.',
                  );
                  if (!ok) return;
                  await repo.deletePlaylist(p.id);
                  ref.invalidate(playlistsProvider(p.libraryId));
                  if (context.mounted) context.pop();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'rename', child: Text('Rename')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
        ],
      ),
      body: auth == null
          ? const SizedBox.shrink()
          : async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Failed to load playlist: $e')),
              data: (p) {
                final items = _local ?? p.items;
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${items.length} items · ${formatDuration(p.totalDuration)}',
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: items.isEmpty
                                ? null
                                : () => _playQueue(context, ref, p.name, items, 0),
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Play all'),
                          ),
                          IconButton(
                            tooltip: 'Download all',
                            icon: const Icon(Icons.download_outlined),
                            onPressed: () async {
                              final n = await downloadBooks(
                                context,
                                ref,
                                items.where((i) => i.episodeId == null).map((i) => i.libraryItemId),
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Queued $n downloads')),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: items.isEmpty
                          ? const Center(child: Text('This playlist is empty.'))
                          : ReorderableListView.builder(
                              buildDefaultDragHandles: true,
                              itemCount: items.length,
                              onReorder: (a, b) => _reorder(p, a, b),
                              itemBuilder: (context, i) {
                                final it = items[i];
                                return ListTile(
                                  key: ValueKey('${it.downloadId}#$i'),
                                  leading: it.item == null
                                      ? const Icon(Icons.audiotrack)
                                      : CoverImage(
                                          url: coverImageUrl(
                                            serverUrl: auth.serverUrl,
                                            itemId: it.item!.id,
                                            token: auth.token,
                                            updatedAt: it.item!.updatedAt,
                                          ),
                                          width: 48,
                                          height: 48,
                                        ),
                                  title: Text(it.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  subtitle: Text(it.item?.authorOrPublisherName ?? ''),
                                  onTap: () => it.episodeId == null
                                      ? _playQueue(context, ref, p.name, items, i)
                                      : context.push('/item/${it.libraryItemId}'),
                                  trailing: Padding(
                                    padding: const EdgeInsets.only(right: 32),
                                    child: IconButton(
                                      tooltip: 'Remove',
                                      icon: const Icon(Icons.remove_circle_outline),
                                      onPressed: () async {
                                        await repo.removeFromPlaylist(
                                          p.id,
                                          it.libraryItemId,
                                          episodeId: it.episodeId,
                                        );
                                        ref.invalidate(playlistDetailProvider(p.id));
                                        ref.invalidate(playlistsProvider(p.libraryId));
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}
