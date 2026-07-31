import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/cover_image_url.dart';
import '../../core/network/socket_service.dart';
import '../../models/library.dart';
import '../../models/library_item.dart';
import '../../models/personalized_shelf.dart';
import '../../widgets/cover_image.dart';
import '../auth/state/session_controller.dart';
import '../auth/state/session_state.dart';
import '../downloads/state/download_controller.dart';
import '../player/mini_player.dart';
import 'state/library_providers.dart';

/// PLAN.md Phase 4.2 (libraries + switcher) and 4.3 (personalized home
/// shelves, rendered generically by shelf type rather than hardcoding each
/// row — see PersonalizedShelf). Single default look per Phase 1.8; the
/// bookshelf-vs-grid skin divergence is Milestone 3.
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

    final librariesAsync = ref.watch(librariesProvider);

    return Scaffold(
      appBar: AppBar(
        title: librariesAsync.maybeWhen(
          data: (libraries) {
            if (libraries.isEmpty) return const Text('Steeped');
            final selectedId =
                ref.watch(selectedLibraryIdProvider) ?? libraries.first.id;
            final selected = libraries.firstWhere(
              (l) => l.id == selectedId,
              orElse: () => libraries.first,
            );
            if (libraries.length == 1) return Text(selected.name);
            return _LibraryPicker(libraries: libraries, selectedId: selectedId);
          },
          orElse: () => const Text('Steeped'),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: _ConnectionBadge(status: ref.watch(socketServiceProvider)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.download_done_outlined),
            tooltip: 'Downloads',
            onPressed: () => context.push('/downloads'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () =>
                ref.read(sessionControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: librariesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load libraries: $error')),
        data: (libraries) {
          if (libraries.isEmpty) {
            return const Center(child: Text('No libraries on this server.'));
          }
          final libraryId =
              ref.watch(selectedLibraryIdProvider) ?? libraries.first.id;
          final selected = libraries.firstWhere(
            (l) => l.id == libraryId,
            orElse: () => libraries.first,
          );
          return _LibraryHome(
            libraryId: libraryId,
            isPodcast: selected.isPodcastLibrary,
            serverUrl: session.serverUrl,
            token: session.user.effectiveToken,
          );
        },
      ),
      bottomNavigationBar: const MiniPlayer(),
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

class _LibraryHome extends ConsumerWidget {
  const _LibraryHome({
    required this.libraryId,
    required this.isPodcast,
    required this.serverUrl,
    required this.token,
  });

  final String libraryId;
  final bool isPodcast;
  final String serverUrl;
  final String? token;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shelvesAsync = ref.watch(personalizedShelvesProvider(libraryId));

    return RefreshIndicator(
      onRefresh: () => ref.refresh(personalizedShelvesProvider(libraryId).future),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton.tonal(
              onPressed: () => context.push('/library/$libraryId'),
              child: const Text('Browse Full Library'),
            ),
          ),
          // PLAN.md Phase 7.6: quick access to the newest episodes across a
          // podcast library.
          if (isPodcast) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                onPressed: () =>
                    context.push('/library/$libraryId/recent-episodes'),
                icon: const Icon(Icons.podcasts),
                label: const Text('Latest Episodes'),
              ),
            ),
          ],
          const SizedBox(height: 16),
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
              ShelfEntityType.series => _LabelCard(text: shelf.seriesEntries[index]),
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
