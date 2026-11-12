import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/app_database.dart';
import '../../models/library_item.dart';
import '../../models/library_item_detail.dart';
import '../auth/state/session_controller.dart' show activeProfileIdProvider;
import '../library/state/library_providers.dart';
import 'item_links_store.dart';
import 'link_matching.dart';

/// The title before any subtitle, as typed (searching the full title with a
/// subtitle on one side finds nothing on the other).
String mainTitleOf(String title) =>
    title.split(RegExp(r'\s[-–—]\s|:')).first.trim();

final itemLinksStoreProvider = Provider<ItemLinksStore>(
  (ref) => ItemLinksStore(
    ref.watch(appDatabaseProvider),
    profileId: ref.watch(activeProfileIdProvider) ?? '',
  ),
);

/// The saved link for an item (either side), or null.
final itemLinkProvider = FutureProvider.autoDispose.family<ItemLink?, String>(
  (ref, itemId) => ref.watch(itemLinksStoreProvider).forItem(itemId),
);

LinkKey linkKeyOfDetail(LibraryItemDetail d) => LinkKey(
  id: d.id,
  title: d.title,
  author: d.authorNames,
  asin: d.asin,
  isbn: d.isbn,
  seriesName: d.series.isEmpty ? null : d.series.first.name,
  seriesSequence: d.series.isEmpty ? null : d.series.first.sequence,
);

LinkKey linkKeyOfItem(LibraryItem i) => LinkKey(
  id: i.id,
  title: i.title,
  author: i.authorOrPublisherName,
  asin: i.asin,
  isbn: i.isbn,
  seriesName: i.seriesName,
  seriesSequence: i.seriesSequence,
);

class LinkSuggestion {
  const LinkSuggestion(this.item, this.reason);

  final LibraryItem item;
  final LinkReason reason;
}

/// Items in any library whose title matches [query] and that are the other
/// format of [source]: an ebook-only item for an audiobook, an item with audio
/// for an ebook-only one.
Future<List<LibraryItem>> _otherFormatItems(
  Ref ref,
  LibraryItemDetail source,
  String query,
) async {
  final repo = ref.watch(libraryRepositoryProvider);
  final libraries = await ref.watch(librariesProvider.future);
  final wantAudio = source.isEbookOnly;
  final found = <String, LibraryItem>{};
  for (final lib in libraries) {
    if (lib.mediaType != 'book') continue;
    try {
      final res = await repo.search(lib.id, query);
      for (final b in res.books) {
        if (b.id == source.id) continue;
        if (wantAudio ? b.hasAudio : (b.hasEbook && !b.hasAudio)) {
          found[b.id] = b;
        }
      }
    } catch (_) {
      // A library that fails to search is skipped.
    }
  }
  return found.values.toList();
}

/// Likely matches for an item, ranked ASIN, ISBN, then author + title. The
/// search is by title (the server has no ASIN/ISBN search); a book whose
/// title is spelled differently is found with [linkSearchProvider] instead.
final linkSuggestionsProvider = FutureProvider.autoDispose
    .family<List<LinkSuggestion>, String>((ref, itemId) async {
      final source = await ref.watch(itemDetailProvider(itemId).future);
      final items = await _otherFormatItems(
        ref,
        source,
        mainTitleOf(source.title),
      );
      final byId = {for (final i in items) i.id: i};
      return [
        for (final c in findLinkCandidates(
          linkKeyOfDetail(source),
          items.map(linkKeyOfItem),
        ))
          LinkSuggestion(byId[c.key.id]!, c.reason),
      ];
    });

/// Manual search: every other-format book whose title matches what the user
/// typed, with no further matching, for books the automatic rules miss.
final linkSearchProvider = FutureProvider.autoDispose
    .family<List<LibraryItem>, (String, String)>((ref, args) async {
      final source = await ref.watch(itemDetailProvider(args.$1).future);
      return _otherFormatItems(ref, source, args.$2);
    });

/// Ebook fraction a reader should open at on its next start, set by a switch
/// from the audiobook (item id -> 0..1). Consumed once.
final pendingEbookJumpProvider = StateProvider<Map<String, double>>(
  (ref) => const {},
);
