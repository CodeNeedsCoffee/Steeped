import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'library_browse_widgets.dart';
import 'library_grid_screen.dart';
import 'library_toolbar.dart';

enum LibrarySection {
  books('Books'),
  authors('Authors'),
  collections('Collections'),
  playlists('Playlists');

  const LibrarySection(this.label);
  final String label;
}

/// Remembered per library for the life of the app session.
final librarySectionProvider = StateProvider.family<LibrarySection, String>(
  (ref, libraryId) => LibrarySection.books,
);

/// LIBRARY_PLAN.md L2: the Library tab's body: a Books | Authors |
/// Collections | Playlists sub-filter above the matching view. Podcast
/// libraries only get Books and Playlists.
class LibraryBrowseTab extends ConsumerWidget {
  const LibraryBrowseTab({
    required this.libraryId,
    required this.isPodcast,
    required this.topPadding,
    super.key,
  });

  final String libraryId;
  final bool isPodcast;
  final double topPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = isPodcast
        ? [LibrarySection.books, LibrarySection.playlists]
        : LibrarySection.values;
    var section = ref.watch(librarySectionProvider(libraryId));
    if (!sections.contains(section)) section = LibrarySection.books;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, topPadding, 16, 4),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<LibrarySection>(
              showSelectedIcon: false,
              segments: [
                for (final s in sections)
                  ButtonSegment(value: s, label: Text(s.label)),
              ],
              selected: {section},
              onSelectionChanged: (s) => ref
                  .read(librarySectionProvider(libraryId).notifier)
                  .state = s.first,
            ),
          ),
        ),
        Expanded(
          child: switch (section) {
            LibrarySection.books => Column(
              children: [
                LibraryToolbar(libraryId: libraryId),
                Expanded(
                  child: LibraryItemsGrid(libraryId: libraryId, topPadding: 4),
                ),
              ],
            ),
            LibrarySection.authors => AuthorsView(libraryId: libraryId),
            LibrarySection.collections => CollectionsView(libraryId: libraryId),
            LibrarySection.playlists => PlaylistsView(libraryId: libraryId),
          },
        ),
      ],
    );
  }
}
