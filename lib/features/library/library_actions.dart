import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/library_item.dart';
import '../auth/state/session_controller.dart';
import '../auth/state/session_state.dart';
import '../downloads/state/download_controller.dart';
import '../player/now_playing_navigation.dart';
import '../player/state/playback_controller.dart';
import 'state/library_providers.dart';

/// Whether the signed-in account may change shared server data
/// (collections). Playlists are per-user and always allowed.
bool canEditCollections(WidgetRef ref) {
  final s = ref.read(sessionControllerProvider);
  if (s is! SessionAuthenticated) return false;
  final t = s.user.type;
  return t == 'root' || t == 'admin' || s.user.canUpdate;
}

void _snack(BuildContext context, String text) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

Future<String?> promptForName(
  BuildContext context, {
  required String title,
  String initial = '',
  String action = 'Save',
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Name'),
        onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text.trim()),
          child: Text(action),
        ),
      ],
    ),
  ).then((v) => (v == null || v.isEmpty) ? null : v);
}

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String action = 'Delete',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(action),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// LIBRARY_PLAN.md L3: choose an existing playlist (or create one) to add a
/// book to. Tapping a playlist that already has the book removes it.
Future<void> showAddToPlaylistSheet(
  BuildContext context,
  WidgetRef ref, {
  required String libraryId,
  required String libraryItemId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => Consumer(
      builder: (sheetContext, ref, _) {
        final async = ref.watch(playlistsProvider(libraryId));
        final repo = ref.read(libraryRepositoryProvider);
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.6,
            ),
            child: async.when(
              loading: () => const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load playlists: $e'),
              ),
              data: (playlists) => ListView(
                shrinkWrap: true,
                children: [
                  const ListTile(title: Text('Add to playlist')),
                  ListTile(
                    leading: const Icon(Icons.add),
                    title: const Text('New playlist…'),
                    onTap: () async {
                      final name = await promptForName(
                        sheetContext,
                        title: 'New playlist',
                        action: 'Create',
                      );
                      if (name == null) return;
                      try {
                        await repo.createPlaylist(
                          libraryId: libraryId,
                          name: name,
                          items: [(libraryItemId: libraryItemId, episodeId: null)],
                        );
                        ref.invalidate(playlistsProvider(libraryId));
                        if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                        _snack(context, 'Added to "$name"');
                      } catch (e) {
                        _snack(context, 'Could not create playlist: $e');
                      }
                    },
                  ),
                  for (final p in playlists)
                    ListTile(
                      leading: Icon(
                        p.contains(libraryItemId)
                            ? Icons.check_circle
                            : Icons.playlist_add,
                      ),
                      title: Text(p.name),
                      subtitle: Text('${p.items.length} items'),
                      onTap: () async {
                        try {
                          if (p.contains(libraryItemId)) {
                            await repo.removeFromPlaylist(p.id, libraryItemId);
                          } else {
                            await repo.addToPlaylist(p.id, libraryItemId);
                          }
                          ref.invalidate(playlistsProvider(libraryId));
                          ref.invalidate(playlistDetailProvider(p.id));
                        } catch (e) {
                          _snack(context, 'Playlist update failed: $e');
                        }
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// Same idea for server collections; only offered when permitted.
Future<void> showAddToCollectionSheet(
  BuildContext context,
  WidgetRef ref, {
  required String libraryId,
  required String bookId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => Consumer(
      builder: (sheetContext, ref, _) {
        final async = ref.watch(collectionsProvider(libraryId));
        final repo = ref.read(libraryRepositoryProvider);
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.6,
            ),
            child: async.when(
              loading: () => const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load collections: $e'),
              ),
              data: (collections) => ListView(
                shrinkWrap: true,
                children: [
                  const ListTile(title: Text('Add to collection')),
                  ListTile(
                    leading: const Icon(Icons.add),
                    title: const Text('New collection…'),
                    onTap: () async {
                      final name = await promptForName(
                        sheetContext,
                        title: 'New collection',
                        action: 'Create',
                      );
                      if (name == null) return;
                      try {
                        await repo.createCollection(
                          libraryId: libraryId,
                          name: name,
                          bookIds: [bookId],
                        );
                        ref.invalidate(collectionsProvider(libraryId));
                        if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                        _snack(context, 'Added to "$name"');
                      } catch (e) {
                        _snack(context, 'Could not create collection: $e');
                      }
                    },
                  ),
                  for (final c in collections)
                    ListTile(
                      leading: Icon(
                        c.books.any((b) => b.id == bookId)
                            ? Icons.check_circle
                            : Icons.collections_bookmark_outlined,
                      ),
                      title: Text(c.name),
                      subtitle: Text('${c.books.length} books'),
                      onTap: () async {
                        try {
                          if (c.books.any((b) => b.id == bookId)) {
                            await repo.removeBookFromCollection(c.id, bookId);
                          } else {
                            await repo.addBookToCollection(c.id, bookId);
                          }
                          ref.invalidate(collectionsProvider(libraryId));
                          ref.invalidate(collectionDetailProvider(c.id));
                        } catch (e) {
                          _snack(context, 'Collection update failed: $e');
                        }
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// LIBRARY_PLAN.md L6: the long-press sheet shared by grids, shelves and
/// search results.
Future<void> showItemQuickActions(
  BuildContext context,
  WidgetRef ref,
  LibraryItem item,
) {
  final libraryId = item.libraryId ?? ref.read(selectedLibraryIdProvider);
  final isBook = item.mediaType == 'book';
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Wrap(
        children: [
          ListTile(
            title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: item.authorOrPublisherName == null
                ? null
                : Text(item.authorOrPublisherName!),
          ),
          if (isBook)
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: const Text('Play'),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                await ref.read(playbackControllerProvider.notifier).playItem(item.id);
                if (context.mounted &&
                    ref.read(currentPlaybackItemProvider)?.id == item.id) {
                  openNowPlaying(context, ref);
                }
              },
            ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Details'),
            onTap: () {
              Navigator.of(sheetContext).pop();
              context.push('/item/${item.id}');
            },
          ),
          if (isBook)
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('Download'),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                final s = ref.read(sessionControllerProvider);
                if (s is! SessionAuthenticated) return;
                try {
                  final detail = await ref
                      .read(libraryRepositoryProvider)
                      .fetchItemDetail(item.id);
                  await ref
                      .read(downloadControllerProvider.notifier)
                      .download(
                        item: detail,
                        serverUrl: s.serverUrl,
                        token: s.user.effectiveToken,
                      );
                  _snack(context, 'Download started');
                } catch (e) {
                  _snack(context, 'Download failed: $e');
                }
              },
            ),
          if (isBook && libraryId != null)
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: const Text('Add to playlist'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                showAddToPlaylistSheet(
                  context,
                  ref,
                  libraryId: libraryId,
                  libraryItemId: item.id,
                );
              },
            ),
          if (isBook && libraryId != null && canEditCollections(ref))
            ListTile(
              leading: const Icon(Icons.collections_bookmark_outlined),
              title: const Text('Add to collection'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                showAddToCollectionSheet(
                  context,
                  ref,
                  libraryId: libraryId,
                  bookId: item.id,
                );
              },
            ),
          if (isBook && item.duration != null) ...[
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: const Text('Mark finished'),
              onTap: () => _markFinished(sheetContext, ref, item, true),
            ),
            ListTile(
              leading: const Icon(Icons.restart_alt),
              title: const Text('Mark not finished'),
              onTap: () => _markFinished(sheetContext, ref, item, false),
            ),
          ],
        ],
      ),
    ),
  );
}

Future<void> _markFinished(
  BuildContext sheetContext,
  WidgetRef ref,
  LibraryItem item,
  bool finished,
) async {
  final messenger = ScaffoldMessenger.of(sheetContext);
  Navigator.of(sheetContext).pop();
  try {
    await ref.read(progressRepositoryProvider).updateProgress(
      libraryItemId: item.id,
      currentTime: finished ? item.duration! : 0,
      duration: item.duration!,
      isFinished: finished,
    );
    messenger.showSnackBar(
      SnackBar(content: Text(finished ? 'Marked finished' : 'Marked not finished')),
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Could not update: $e')));
  }
}

/// Queue a download for every book in [items] not already on the device.
Future<int> downloadBooks(
  BuildContext context,
  WidgetRef ref,
  Iterable<String> itemIds,
) async {
  final s = ref.read(sessionControllerProvider);
  if (s is! SessionAuthenticated) return 0;
  var queued = 0;
  for (final id in itemIds) {
    try {
      final detail = await ref.read(libraryRepositoryProvider).fetchItemDetail(id);
      if (detail.tracks.isEmpty) continue;
      await ref
          .read(downloadControllerProvider.notifier)
          .download(item: detail, serverUrl: s.serverUrl, token: s.user.effectiveToken);
      queued++;
    } catch (_) {}
  }
  return queued;
}
