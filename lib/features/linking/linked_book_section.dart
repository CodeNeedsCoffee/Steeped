import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../models/library_item.dart';
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
      builder: (_) => _LinkDialog(item: item),
    );
  }
}

class _LinkDialog extends ConsumerStatefulWidget {
  const _LinkDialog({required this.item});

  final LibraryItemDetail item;

  @override
  ConsumerState<_LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends ConsumerState<_LinkDialog> {
  final _controller = TextEditingController();
  String _query = '';

  bool get _isAudio => !widget.item.isEbookOnly;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _link(LibraryItem other, LinkSource source) async {
    final item = widget.item;
    await ref
        .read(itemLinksStoreProvider)
        .save(
          ItemLink(
            audioItemId: _isAudio ? item.id : other.id,
            ebookItemId: _isAudio ? other.id : item.id,
            source: source,
          ),
        );
    ref.invalidate(itemLinkProvider(item.id));
    ref.invalidate(itemLinkProvider(other.id));
    if (mounted) Navigator.of(context).pop();
  }

  Widget _tile(LibraryItem b, LinkSource source, {LinkReason? reason}) =>
      ListTile(
        title: Text(b.title),
        subtitle: Text(
          [
            if (b.authorOrPublisherName != null) b.authorOrPublisherName!,
            if (reason != null)
              context.l10n.linkBookMatchedBy(_reasonLabel(context, reason)),
          ].join(' · '),
        ),
        onTap: () => _link(b, source),
      );

  @override
  Widget build(BuildContext context) {
    final searching = _query.isNotEmpty;
    final results = searching
        ? ref
              .watch(linkSearchProvider((widget.item.id, _query)))
              .whenData(
                (list) => [for (final b in list) _tile(b, LinkSource.manual)],
              )
        : ref
              .watch(linkSuggestionsProvider(widget.item.id))
              .whenData(
                (list) => [
                  for (final s in list)
                    _tile(s.item, LinkSource.auto, reason: s.reason),
                ],
              );
    return AlertDialog(
      title: Text(context.l10n.linkBookPick),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: results.when(
                loading: () => const SizedBox(
                  height: 64,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text(context.l10n.failedToLoad(e)),
                data: (tiles) => tiles.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(context.l10n.linkBookNone),
                      )
                    : ListView(shrinkWrap: true, children: tiles),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: context.l10n.linkBookSearch,
                suffixIcon: const Icon(Icons.search),
              ),
              onSubmitted: (v) => setState(() => _query = v.trim()),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
      ],
    );
  }
}
