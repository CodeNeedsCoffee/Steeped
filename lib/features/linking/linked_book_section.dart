import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../models/library_item_detail.dart';
import '../library/state/library_providers.dart';
import 'item_links_store.dart';
import 'link_matching.dart';
import 'link_providers.dart';
import 'link_switch.dart';

String _reasonLabel(BuildContext context, LinkReason r) => switch (r) {
  LinkReason.asin => context.l10n.linkReasonAsin,
  LinkReason.isbn => context.l10n.linkReasonIsbn,
  LinkReason.authorTitle => context.l10n.linkReasonAuthorTitle,
};

/// J1/J2: on an item that is only one format, link it to the other format's
/// item and jump between them. An item that already has both formats needs
/// neither (its own Play and Read buttons switch).
class LinkedBookSection extends ConsumerWidget {
  const LinkedBookSection({required this.item, super.key});

  final LibraryItemDetail item;

  bool get _isAudio => !item.isEbookOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (item.isPodcast || (item.hasEbook && !item.isEbookOnly)) {
      return const SizedBox.shrink();
    }
    final link = ref.watch(itemLinkProvider(item.id)).valueOrNull;
    if (link == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Center(
          child: TextButton.icon(
            onPressed: () => _suggest(context, ref),
            icon: const Icon(Icons.link),
            label: Text(context.l10n.linkBook),
          ),
        ),
      );
    }
    final otherId = link.otherSide(item.id);
    final other = ref.watch(itemDetailProvider(otherId)).valueOrNull;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        child: ListTile(
          leading: const Icon(Icons.link),
          title: Text(
            _isAudio ? context.l10n.linkedEbook : context.l10n.linkedAudiobook,
          ),
          subtitle: Text(other?.title ?? ''),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.tonal(
                onPressed: other == null
                    ? null
                    : () => _isAudio
                          ? switchToEbook(
                              context,
                              ref,
                              audio: item,
                              ebook: other,
                            )
                          : switchToAudio(
                              context,
                              ref,
                              audio: other,
                              ebook: item,
                            ),
                child: Text(
                  _isAudio
                      ? context.l10n.readLinked
                      : context.l10n.listenLinked,
                ),
              ),
              IconButton(
                tooltip: context.l10n.unlinkBook,
                icon: const Icon(Icons.link_off),
                onPressed: () async {
                  await ref.read(itemLinksStoreProvider).remove(item.id);
                  ref.invalidate(itemLinkProvider(item.id));
                  ref.invalidate(itemLinkProvider(otherId));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _suggest(BuildContext context, WidgetRef ref) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final suggestions = ref.watch(linkSuggestionsProvider(item.id));
          return AlertDialog(
            title: Text(ctx.l10n.linkBookPick),
            content: SizedBox(
              width: double.maxFinite,
              child: suggestions.when(
                loading: () => const SizedBox(
                  height: 64,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text(ctx.l10n.failedToLoad(e)),
                data: (list) => list.isEmpty
                    ? Text(ctx.l10n.linkBookNone)
                    : ListView(
                        shrinkWrap: true,
                        children: [
                          for (final s in list)
                            ListTile(
                              title: Text(s.item.title),
                              subtitle: Text(
                                [
                                  if (s.item.authorOrPublisherName != null)
                                    s.item.authorOrPublisherName!,
                                  ctx.l10n.linkBookMatchedBy(
                                    _reasonLabel(ctx, s.reason),
                                  ),
                                ].join(' · '),
                              ),
                              onTap: () async {
                                final audioId = _isAudio ? item.id : s.item.id;
                                final ebookId = _isAudio ? s.item.id : item.id;
                                await ref
                                    .read(itemLinksStoreProvider)
                                    .save(
                                      ItemLink(
                                        audioItemId: audioId,
                                        ebookItemId: ebookId,
                                        source: LinkSource.auto,
                                      ),
                                    );
                                ref.invalidate(itemLinkProvider(item.id));
                                ref.invalidate(itemLinkProvider(s.item.id));
                                if (ctx.mounted) Navigator.of(ctx).pop();
                              },
                            ),
                        ],
                      ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
              ),
            ],
          );
        },
      ),
    );
  }
}
