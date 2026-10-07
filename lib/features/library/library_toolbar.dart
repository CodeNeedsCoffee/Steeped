import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/library_query.dart';
import 'state/library_providers.dart';

/// LIBRARY_PLAN.md L4: sort menu, filter sheet, grid/list toggle and the
/// active-filter chip, shown above the Books grid.
class LibraryToolbar extends ConsumerWidget {
  const LibraryToolbar({required this.libraryId, super.key});

  final String libraryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(libraryQueryProvider(libraryId));
    final controller = ref.read(libraryQueryProvider(libraryId).notifier);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Column(
        children: [
          Row(
            children: [
              PopupMenuButton<LibrarySort>(
                tooltip: 'Sort',
                onSelected: (s) => controller.update(
                  s == query.sort
                      ? query.copyWith(desc: !query.desc)
                      : query.copyWith(sort: s, desc: false),
                ),
                itemBuilder: (context) => [
                  for (final s in LibrarySort.values)
                    CheckedPopupMenuItem(
                      value: s,
                      checked: s == query.sort,
                      child: Text(s.label),
                    ),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sort, size: 20),
                      const SizedBox(width: 6),
                      Text(query.sort.label),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: query.desc ? 'Descending' : 'Ascending',
                icon: Icon(
                  query.desc ? Icons.arrow_downward : Icons.arrow_upward,
                  size: 20,
                ),
                onPressed: () =>
                    controller.update(query.copyWith(desc: !query.desc)),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Filter',
                icon: Icon(
                  query.hasFilter ? Icons.filter_alt : Icons.filter_alt_outlined,
                ),
                onPressed: () => showLibraryFilterSheet(context, libraryId),
              ),
              IconButton(
                tooltip: query.viewMode == LibraryViewMode.grid
                    ? 'List view'
                    : 'Grid view',
                icon: Icon(
                  query.viewMode == LibraryViewMode.grid
                      ? Icons.view_list
                      : Icons.grid_view,
                ),
                onPressed: () => controller.update(
                  query.copyWith(
                    viewMode: query.viewMode == LibraryViewMode.grid
                        ? LibraryViewMode.list
                        : LibraryViewMode.grid,
                  ),
                ),
              ),
            ],
          ),
          if (query.hasFilter)
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                children: [
                  InputChip(
                    label: Text(
                      '${query.filterGroup!.label}: ${query.filterLabel}',
                    ),
                    onDeleted: () => controller.update(query.withoutFilter()),
                  ),
                  ActionChip(
                    label: const Text('Clear all'),
                    onPressed: () => controller.update(query.withoutFilter()),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

Future<void> showLibraryFilterSheet(BuildContext context, String libraryId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _FilterSheet(libraryId: libraryId),
  );
}

class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet({required this.libraryId});

  final String libraryId;

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  LibraryFilterGroup? _group;

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(libraryFilterDataProvider(widget.libraryId));
    final height = MediaQuery.sizeOf(context).height * 0.7;
    return SizedBox(
      height: height,
      child: dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load filters: $e')),
        data: (data) {
          final options = _optionsFor(data);
          if (_group == null) {
            return ListView(
              children: [
                const ListTile(title: Text('Filter by')),
                for (final g in LibraryFilterGroup.values)
                  ListTile(
                    title: Text(g.label),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => setState(() => _group = g),
                  ),
              ],
            );
          }
          return Column(
            children: [
              ListTile(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => setState(() => _group = null),
                ),
                title: Text(_group!.label),
              ),
              Expanded(
                child: options.isEmpty
                    ? const Center(child: Text('Nothing to filter on.'))
                    : ListView(
                        children: [
                          for (final o in options)
                            ListTile(
                              title: Text(o.label),
                              onTap: () {
                                final c = ref.read(
                                  libraryQueryProvider(widget.libraryId)
                                      .notifier,
                                );
                                c.update(
                                  ref
                                      .read(
                                        libraryQueryProvider(widget.libraryId),
                                      )
                                      .withFilter(
                                        _group!,
                                        o.value,
                                        label: o.label,
                                      ),
                                );
                                Navigator.of(context).pop();
                              },
                            ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<({String value, String label})> _optionsFor(LibraryFilterData d) {
    List<({String value, String label})> plain(List<String> l) => [
      for (final s in l) (value: s, label: s),
    ];
    List<({String value, String label})> idNames(
      List<({String id, String name})> l,
    ) => [for (final s in l) (value: s.id, label: s.name)];
    return switch (_group) {
      LibraryFilterGroup.genres => plain(d.genres),
      LibraryFilterGroup.tags => plain(d.tags),
      LibraryFilterGroup.narrators => plain(d.narrators),
      LibraryFilterGroup.languages => plain(d.languages),
      LibraryFilterGroup.authors => idNames(d.authors),
      LibraryFilterGroup.series => idNames(d.series),
      LibraryFilterGroup.progress => [
        for (final e in progressFilterValues.entries)
          (value: e.key, label: e.value),
      ],
      null => const [],
    };
  }
}
