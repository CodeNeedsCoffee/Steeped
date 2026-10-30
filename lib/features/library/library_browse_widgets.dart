import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/cover_image_url.dart';
import '../../models/library_browse.dart';
import '../../models/library_item.dart';
import '../../widgets/cover_image.dart';
import '../auth/state/session_controller.dart';
import '../auth/state/session_state.dart';
import 'library_actions.dart';
import 'state/library_providers.dart';
import '../../core/utils/format_duration.dart';
import '../../l10n/l10n.dart';

({String serverUrl, String? token})? sessionAuth(WidgetRef ref) {
  final s = ref.watch(sessionControllerProvider);
  if (s is! SessionAuthenticated) return null;
  return (serverUrl: s.serverUrl, token: s.user.effectiveToken);
}

String formatDuration(BuildContext context, double seconds) =>
    formatDurationText(context.l10n, seconds);

/// Up to four covers in a 2x2 mosaic (a single cover fills the tile).
class CoverMosaic extends StatelessWidget {
  const CoverMosaic({
    required this.items,
    required this.serverUrl,
    required this.token,
    this.size = 56,
    super.key,
  });

  final List<LibraryItem> items;
  final String serverUrl;
  final String? token;
  final double size;

  @override
  Widget build(BuildContext context) {
    Widget cover(LibraryItem i, double s) => CoverImage(
      url: coverImageUrl(
        serverUrl: serverUrl,
        itemId: i.id,
        token: token,
        updatedAt: i.updatedAt,
      ),
      width: s,
      height: s,
    );
    final shown = items.take(4).toList();
    if (shown.isEmpty) {
      return SizedBox(
        width: size,
        height: size,
        child: const Icon(Icons.queue_music),
      );
    }
    if (shown.length < 4) return cover(shown.first, size);
    final half = size / 2;
    return SizedBox(
      width: size,
      height: size,
      child: Wrap(children: [for (final i in shown) cover(i, half)]),
    );
  }
}

class AuthorAvatar extends StatelessWidget {
  const AuthorAvatar({
    required this.author,
    required this.serverUrl,
    required this.token,
    this.size = 96,
    super.key,
  });

  final Author author;
  final String serverUrl;
  final String? token;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (!author.hasImage) {
      return CircleAvatar(
        radius: size / 2,
        child: Text(
          author.name.isEmpty ? '?' : author.name[0].toUpperCase(),
          style: TextStyle(fontSize: size / 3),
        ),
      );
    }
    final url = Uri.parse('$serverUrl/api/authors/${author.id}/image').replace(
      queryParameters: {
        'ts': '${author.updatedAt}',
        if (token != null) 'token': token!,
      },
    ).toString();
    return ClipOval(child: CoverImage(url: url, width: size, height: size));
  }
}

class AuthorsView extends ConsumerWidget {
  const AuthorsView({required this.libraryId, this.topPadding = 8, super.key});

  final String libraryId;
  final double topPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = sessionAuth(ref);
    final async = ref.watch(authorsProvider(libraryId));
    if (auth == null) return const SizedBox.shrink();
    return RefreshIndicator(
      onRefresh: () async => ref.refresh(authorsProvider(libraryId).future),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          children: [Center(child: Text(context.l10n.failedToLoadAuthors(e)))],
        ),
        data: (authors) {
          if (authors.isEmpty) {
            return ListView(
              children: [Center(child: Text(context.l10n.noAuthorsInThisLibrary))],
            );
          }
          return GridView.builder(
            padding: EdgeInsets.fromLTRB(16, topPadding, 16, 16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 130,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.78,
            ),
            itemCount: authors.length,
            itemBuilder: (context, i) {
              final a = authors[i];
              return InkWell(
                onTap: () => context.push('/author/${a.id}'),
                child: Column(
                  children: [
                    AuthorAvatar(
                      author: a,
                      serverUrl: auth.serverUrl,
                      token: auth.token,
                      size: 84,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      a.name,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      context.l10n.bookCount(a.numBooks),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class CollectionsView extends ConsumerWidget {
  const CollectionsView({required this.libraryId, this.topPadding = 8, super.key});

  final String libraryId;
  final double topPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = sessionAuth(ref);
    final async = ref.watch(collectionsProvider(libraryId));
    if (auth == null) return const SizedBox.shrink();
    final canEdit = canEditCollections(ref);
    return RefreshIndicator(
      onRefresh: () async => ref.refresh(collectionsProvider(libraryId).future),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          children: [Center(child: Text(context.l10n.failedToLoadCollections(e)))],
        ),
        data: (collections) => ListView(
          padding: EdgeInsets.only(top: topPadding, bottom: 16),
          children: [
            if (canEdit)
              ListTile(
                leading: const Icon(Icons.add),
                title: Text(context.l10n.newCollection),
                onTap: () async {
                  final name = await promptForName(
                    context,
                    title: context.l10n.newCollectionEllipsis,
                    action: context.l10n.create,
                  );
                  if (name == null) return;
                  await ref
                      .read(libraryRepositoryProvider)
                      .createCollection(libraryId: libraryId, name: name);
                  ref.invalidate(collectionsProvider(libraryId));
                },
              ),
            if (collections.isEmpty)
              Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text(context.l10n.noCollectionsYet)),
              ),
            for (final c in collections)
              ListTile(
                leading: CoverMosaic(
                  items: c.books,
                  serverUrl: auth.serverUrl,
                  token: auth.token,
                ),
                title: Text(c.name),
                subtitle: Text(
                  context.l10n.bookCountDuration(c.books.length, formatDuration(context, c.totalDuration)),
                ),
                onTap: () => context.push('/collection/${c.id}'),
              ),
          ],
        ),
      ),
    );
  }
}

class PlaylistsView extends ConsumerWidget {
  const PlaylistsView({required this.libraryId, this.topPadding = 8, super.key});

  final String libraryId;
  final double topPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = sessionAuth(ref);
    final async = ref.watch(playlistsProvider(libraryId));
    if (auth == null) return const SizedBox.shrink();
    return RefreshIndicator(
      onRefresh: () async => ref.refresh(playlistsProvider(libraryId).future),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          children: [Center(child: Text(context.l10n.failedToLoadPlaylists(e)))],
        ),
        data: (playlists) => ListView(
          padding: EdgeInsets.only(top: topPadding, bottom: 16),
          children: [
            ListTile(
              leading: const Icon(Icons.add),
              title: Text(context.l10n.newPlaylist),
              onTap: () async {
                final name = await promptForName(
                  context,
                  title: context.l10n.newPlaylistEllipsis,
                  action: context.l10n.create,
                );
                if (name == null) return;
                await ref
                    .read(libraryRepositoryProvider)
                    .createPlaylist(libraryId: libraryId, name: name);
                ref.invalidate(playlistsProvider(libraryId));
              },
            ),
            if (playlists.isEmpty)
              Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text(context.l10n.noPlaylistsYet)),
              ),
            for (final p in playlists)
              ListTile(
                leading: CoverMosaic(
                  items: [for (final i in p.items) ?i.item],
                  serverUrl: auth.serverUrl,
                  token: auth.token,
                ),
                title: Text(p.name),
                subtitle: Text(
                  context.l10n.itemCountDuration(p.items.length, formatDuration(context, p.totalDuration)),
                ),
                onTap: () => context.push('/playlist/${p.id}'),
              ),
          ],
        ),
      ),
    );
  }
}
