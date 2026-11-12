import 'package:flutter/material.dart';
import '../../core/utils/html_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/library_browse.dart';
import '../../models/library_item.dart';
import '../../models/library_series.dart';
import '../../widgets/cover_image.dart';
import '../../core/network/cover_image_url.dart';
import '../auth/state/permission_providers.dart';
import '../player/mini_player.dart';
import '../player/now_playing_navigation.dart';
import '../player/state/playback_controller.dart';
import 'author_book_order.dart';
import 'library_actions.dart';
import 'library_browse_widgets.dart';
import 'library_grid_screen.dart';
import 'state/library_providers.dart';
import '../../l10n/l10n.dart';

Future<void> _playQueue(
  BuildContext context,
  WidgetRef ref,
  String name,
  List<PlaylistItem> items,
  int start,
) async {
  final playable = items.where((i) => i.isPlayable).toList();
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
      appBar: AppBar(title: Text(async.valueOrNull?.name ?? context.l10n.author)),
      body: auth == null
          ? const SizedBox.shrink()
          : async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(context.l10n.failedToLoadAuthor(e))),
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
                              plainTextFromHtml(a.description!),
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
                                    onPressed: () => context.push(
                                      '/series/${s.id}',
                                      extra: s,
                                    ),
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
                      itemCount: authorBooksInReadingOrder(a).length,
                      itemBuilder: (context, i) => LibraryBookTile(
                        item: authorBooksInReadingOrder(a)[i],
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
        title: Text(c?.name ?? context.l10n.collection),
        actions: [
          if (c != null && canEdit)
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'rename') {
                  final name = await promptForName(
                    context,
                    title: context.l10n.renameCollection,
                    initial: c.name,
                  );
                  if (name == null) return;
                  await repo.updateCollection(c.id, name: name);
                  ref.invalidate(collectionDetailProvider(c.id));
                  ref.invalidate(collectionsProvider(c.libraryId));
                } else if (v == 'delete') {
                  final ok = await confirmAction(
                    context,
                    title: context.l10n.deleteCollectionTitle,
                    message: context.l10n.deleteCollectionMessage(c.name),
                  );
                  if (!ok) return;
                  await repo.deleteCollection(c.id);
                  ref.invalidate(collectionsProvider(c.libraryId));
                  if (context.mounted) context.pop();
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'rename', child: Text(context.l10n.rename)),
                PopupMenuItem(value: 'delete', child: Text(context.l10n.delete)),
              ],
            ),
        ],
      ),
      body: auth == null
          ? const SizedBox.shrink()
          : async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text(context.l10n.failedToLoadCollection(e))),
              data: (c) => Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.l10n.bookCountDuration(c.books.length, formatDuration(context, c.totalDuration)),
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: !c.books.any((b) => b.hasAudio)
                              ? null
                              : () => _playQueue(context, ref, c.name, [
                                  for (final b in c.books) _asQueueItem(b),
                                ], 0),
                          icon: const Icon(Icons.play_arrow),
                          label: Text(context.l10n.playAll),
                        ),
                        if (ref.watch(canDownloadProvider))
                          IconButton(
                            tooltip: context.l10n.downloadAll,
                            icon: const Icon(Icons.download_outlined),
                            onPressed: () async {
                              final n = await downloadBooks(
                                context,
                                ref,
                                c.books.map((b) => b.id),
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(context.l10n.queuedDownloads(n)),
                                  ),
                                );
                              }
                            },
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: c.books.isEmpty
                        ? Center(child: Text(context.l10n.thisCollectionIsEmpty))
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
                                  title: Text(
                                    b.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(b.authorOrPublisherName ?? ''),
                                  onTap: () => context.push('/item/${b.id}'),
                                  onLongPress: () =>
                                      showItemQuickActions(context, ref, b),
                                  trailing: canEdit
                                      ? IconButton(
                                          tooltip: context.l10n.removeFromCollection,
                                          icon: const Icon(
                                            Icons.remove_circle_outline,
                                          ),
                                          onPressed: () async {
                                            await repo.removeBookFromCollection(
                                              c.id,
                                              b.id,
                                            );
                                            ref.invalidate(
                                              collectionDetailProvider(c.id),
                                            );
                                            ref.invalidate(
                                              collectionsProvider(c.libraryId),
                                            );
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.couldNotReorder(e))));
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
        title: Text(p?.name ?? context.l10n.playlist),
        actions: [
          if (p != null)
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'rename') {
                  final name = await promptForName(
                    context,
                    title: context.l10n.renamePlaylist,
                    initial: p.name,
                  );
                  if (name == null) return;
                  await repo.renamePlaylist(p.id, name);
                  ref.invalidate(playlistDetailProvider(p.id));
                  ref.invalidate(playlistsProvider(p.libraryId));
                } else if (v == 'delete') {
                  final ok = await confirmAction(
                    context,
                    title: context.l10n.deletePlaylistTitle,
                    message: context.l10n.deletePlaylistMessage(p.name),
                  );
                  if (!ok) return;
                  await repo.deletePlaylist(p.id);
                  ref.invalidate(playlistsProvider(p.libraryId));
                  if (context.mounted) context.pop();
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'rename', child: Text(context.l10n.rename)),
                PopupMenuItem(value: 'delete', child: Text(context.l10n.delete)),
              ],
            ),
        ],
      ),
      body: auth == null
          ? const SizedBox.shrink()
          : async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text(context.l10n.failedToLoadPlaylist(e))),
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
                              context.l10n.itemCountDuration(items.length, formatDuration(context, p.totalDuration)),
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: !items.any((i) => i.isPlayable)
                                ? null
                                : () => _playQueue(
                                    context,
                                    ref,
                                    p.name,
                                    items,
                                    0,
                                  ),
                            icon: const Icon(Icons.play_arrow),
                            label: Text(context.l10n.playAll),
                          ),
                          if (ref.watch(canDownloadProvider))
                            IconButton(
                              tooltip: context.l10n.downloadAll,
                              icon: const Icon(Icons.download_outlined),
                              onPressed: () async {
                                final n = await downloadBooks(
                                  context,
                                  ref,
                                  items
                                      .where((i) => i.episodeId == null)
                                      .map((i) => i.libraryItemId),
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(context.l10n.queuedDownloads(n)),
                                    ),
                                  );
                                }
                              },
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: items.isEmpty
                          ? Center(child: Text(context.l10n.thisPlaylistIsEmpty))
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
                                  title: Text(
                                    it.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    it.item?.authorOrPublisherName ?? '',
                                  ),
                                  onTap: () => it.episodeId == null
                                      ? _playQueue(
                                          context,
                                          ref,
                                          p.name,
                                          items,
                                          i,
                                        )
                                      : context.push(
                                          '/item/${it.libraryItemId}',
                                        ),
                                  trailing: Padding(
                                    padding: const EdgeInsets.only(right: 32),
                                    child: IconButton(
                                      tooltip: context.l10n.remove,
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                      ),
                                      onPressed: () async {
                                        await repo.removeFromPlaylist(
                                          p.id,
                                          it.libraryItemId,
                                          episodeId: it.episodeId,
                                        );
                                        ref.invalidate(
                                          playlistDetailProvider(p.id),
                                        );
                                        ref.invalidate(
                                          playlistsProvider(p.libraryId),
                                        );
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
