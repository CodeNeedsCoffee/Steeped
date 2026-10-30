import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/library_item.dart';
import '../auth/state/session_controller.dart';
import '../auth/state/session_state.dart';
import '../auth/state/permission_providers.dart';
import '../downloads/state/download_controller.dart';
import 'series_detail_screen.dart';
import '../player/now_playing_navigation.dart';
import '../player/state/playback_controller.dart';
import 'state/library_providers.dart';
import '../../l10n/l10n.dart';

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
  String? action,
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(labelText: context.l10n.name),
        onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text.trim()),
          child: Text(action ?? context.l10n.save),
        ),
      ],
    ),
  ).then((v) => (v == null || v.isEmpty) ? null : v);
}

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String? action,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(action ?? context.l10n.delete),
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
                child: Text(context.l10n.couldNotLoadPlaylists(e)),
              ),
              data: (playlists) => ListView(
                shrinkWrap: true,
                children: [
                  ListTile(title: Text(context.l10n.addToPlaylist)),
                  ListTile(
                    leading: const Icon(Icons.add),
                    title: Text(context.l10n.newPlaylistEllipsis),
                    onTap: () async {
                      final name = await promptForName(
                        sheetContext,
                        title: sheetContext.l10n.newPlaylistEllipsis,
                        action: sheetContext.l10n.create,
                      );
                      if (name == null) return;
                      try {
                        await repo.createPlaylist(
                          libraryId: libraryId,
                          name: name,
                          items: [
                            (libraryItemId: libraryItemId, episodeId: null),
                          ],
                        );
                        ref.invalidate(playlistsProvider(libraryId));
                        if (sheetContext.mounted)
                          Navigator.of(sheetContext).pop();
                        _snack(context, context.l10n.addedTo(name));
                      } catch (e) {
                        _snack(context, context.l10n.couldNotCreatePlaylist(e));
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
                      subtitle: Text(context.l10n.itemCount(p.items.length)),
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
                          _snack(context, context.l10n.playlistUpdateFailed(e));
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
                child: Text(context.l10n.couldNotLoadCollections(e)),
              ),
              data: (collections) => ListView(
                shrinkWrap: true,
                children: [
                  ListTile(title: Text(context.l10n.addToCollection)),
                  ListTile(
                    leading: const Icon(Icons.add),
                    title: Text(context.l10n.newCollectionEllipsis),
                    onTap: () async {
                      final name = await promptForName(
                        sheetContext,
                        title: sheetContext.l10n.newCollectionEllipsis,
                        action: sheetContext.l10n.create,
                      );
                      if (name == null) return;
                      try {
                        await repo.createCollection(
                          libraryId: libraryId,
                          name: name,
                          bookIds: [bookId],
                        );
                        ref.invalidate(collectionsProvider(libraryId));
                        if (sheetContext.mounted)
                          Navigator.of(sheetContext).pop();
                        _snack(context, context.l10n.addedTo(name));
                      } catch (e) {
                        _snack(context, context.l10n.couldNotCreateCollection(e));
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
                      subtitle: Text(context.l10n.books(c.books.length)),
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
                          _snack(context, context.l10n.collectionUpdateFailed(e));
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
            title: Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: item.authorOrPublisherName == null
                ? null
                : Text(item.authorOrPublisherName!),
          ),
          if (isBook)
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: Text(context.l10n.play),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                await ref
                    .read(playbackControllerProvider.notifier)
                    .playItem(item.id);
                if (context.mounted &&
                    ref.read(currentPlaybackItemProvider)?.id == item.id) {
                  openNowPlaying(context, ref);
                }
              },
            ),
          if (isBook && item.authorOrPublisherName != null)
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(context.l10n.goToAuthor),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _goToAuthorOrSeries(context, ref, item.id, author: true);
              },
            ),
          if (isBook && item.seriesName != null)
            ListTile(
              leading: const Icon(Icons.collections_bookmark_outlined),
              title: Text(context.l10n.goToSeries),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _goToAuthorOrSeries(context, ref, item.id, author: false);
              },
            ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(context.l10n.details),
            onTap: () {
              Navigator.of(sheetContext).pop();
              context.push('/item/${item.id}');
            },
          ),
          if (isBook && ref.read(canDownloadProvider))
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: Text(context.l10n.download),
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
                  _snack(context, context.l10n.downloadStarted);
                } catch (e) {
                  _snack(context, context.l10n.downloadFailed(e));
                }
              },
            ),
          if (isBook && libraryId != null)
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: Text(context.l10n.addToPlaylist),
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
              title: Text(context.l10n.addToCollection),
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
              title: Text(context.l10n.markFinished),
              onTap: () => _markFinished(sheetContext, ref, item, true),
            ),
            ListTile(
              leading: const Icon(Icons.restart_alt),
              title: Text(context.l10n.markNotFinished),
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
  final l10n = sheetContext.l10n;
  Navigator.of(sheetContext).pop();
  try {
    await ref
        .read(progressRepositoryProvider)
        .updateProgress(
          libraryItemId: item.id,
          currentTime: finished ? item.duration! : 0,
          duration: item.duration!,
          isFinished: finished,
        );
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          finished ? l10n.markedFinished : l10n.markedNotFinished,
        ),
      ),
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.couldNotUpdate(e))));
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
      final detail = await ref
          .read(libraryRepositoryProvider)
          .fetchItemDetail(id);
      if (detail.tracks.isEmpty) continue;
      await ref
          .read(downloadControllerProvider.notifier)
          .download(
            item: detail,
            serverUrl: s.serverUrl,
            token: s.user.effectiveToken,
          );
      queued++;
    } catch (_) {}
  }
  return queued;
}

/// Minified list items carry names but not ids, so the author/series ids come
/// from the item's detail. With several authors/series, asks which one.
Future<void> _goToAuthorOrSeries(
  BuildContext context,
  WidgetRef ref,
  String itemId, {
  required bool author,
}) async {
  try {
    final detail = await ref.read(libraryRepositoryProvider).fetchItemDetail(
      itemId,
    );
    final targets = author
        ? [for (final a in detail.authors) (id: a.id, name: a.name)]
        : [for (final s in detail.series) (id: s.id, name: s.name)];
    if (targets.isEmpty) {
      if (context.mounted) _snack(context, context.l10n.notAvailableForThisItem);
      return;
    }
    if (!context.mounted) return;
    String? id = targets.first.id;
    if (targets.length > 1) {
      id = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
          child: Wrap(
            children: [
              for (final t in targets)
                ListTile(
                  title: Text(t.name),
                  onTap: () => Navigator.pop(ctx, t.id),
                ),
            ],
          ),
        ),
      );
    }
    if (id == null || !context.mounted) return;
    if (author) {
      context.push('/author/$id');
    } else {
      final s = detail.series.firstWhere((s) => s.id == id);
      context.push(
        seriesLocation(id, libraryId: detail.libraryId, name: s.name),
      );
    }
  } catch (e) {
    if (context.mounted) _snack(context, context.l10n.couldNotOpen(e));
  }
}
