import 'dart:convert';

/// LIBRARY_PLAN.md L4: sort options, mapped to the server's `sort` values
/// (confirmed in `libraryItemsBookFilters.js`).
enum LibrarySort {
  title('Title', 'media.metadata.title'),
  author('Author', 'media.metadata.authorName'),
  addedAt('Date added', 'addedAt'),
  publishedYear('Published year', 'media.metadata.publishedYear'),
  duration('Duration', 'media.duration'),
  lastProgress('Last played', 'progress'),
  random('Random', 'random');

  const LibrarySort(this.label, this.param);
  final String label;
  final String param;
}

enum LibraryViewMode { grid, list }

enum LibraryFilterGroup {
  genres('Genre'),
  tags('Tag'),
  authors('Author'),
  narrators('Narrator'),
  series('Series'),
  languages('Language'),
  progress('Progress');

  const LibraryFilterGroup(this.label);
  final String label;
}

/// Progress filter values (the server compares the decoded string).
const progressFilterValues = {
  'in-progress': 'In progress',
  'finished': 'Finished',
  'not-started': 'Not started',
  'not-finished': 'Not finished',
};

/// What the Books grid is showing: sort, direction, one optional filter, and
/// the view mode. Persisted per library.
class LibraryQuery {
  const LibraryQuery({
    this.sort = LibrarySort.title,
    this.desc = false,
    this.filterGroup,
    this.filterValue,
    this.filterLabel,
    this.viewMode = LibraryViewMode.grid,
  });

  factory LibraryQuery.fromJson(Map<String, dynamic> json) {
    LibrarySort sort() => LibrarySort.values.firstWhere(
      (s) => s.name == json['sort'],
      orElse: () => LibrarySort.title,
    );
    final group = LibraryFilterGroup.values
        .where((g) => g.name == json['filterGroup'])
        .firstOrNull;
    return LibraryQuery(
      sort: sort(),
      desc: json['desc'] == true,
      filterGroup: group,
      filterValue: group == null ? null : json['filterValue']?.toString(),
      filterLabel: group == null ? null : json['filterLabel']?.toString(),
      viewMode: json['viewMode'] == 'list'
          ? LibraryViewMode.list
          : LibraryViewMode.grid,
    );
  }

  final LibrarySort sort;
  final bool desc;
  final LibraryFilterGroup? filterGroup;

  /// The raw (un-encoded) value, e.g. a genre name or an author id.
  final String? filterValue;

  /// Human label for the chip (author *name* for an id-based filter).
  final String? filterLabel;
  final LibraryViewMode viewMode;

  bool get hasFilter => filterGroup != null && filterValue != null;

  /// `<group>.<base64(value)>`, or null when unfiltered.
  String? get filterParam => hasFilter
      ? '${filterGroup!.name}.${base64.encode(utf8.encode(filterValue!))}'
      : null;

  LibraryQuery copyWith({
    LibrarySort? sort,
    bool? desc,
    LibraryViewMode? viewMode,
  }) => LibraryQuery(
    sort: sort ?? this.sort,
    desc: desc ?? this.desc,
    filterGroup: filterGroup,
    filterValue: filterValue,
    filterLabel: filterLabel,
    viewMode: viewMode ?? this.viewMode,
  );

  LibraryQuery withFilter(
    LibraryFilterGroup group,
    String value, {
    String? label,
  }) => LibraryQuery(
    sort: sort,
    desc: desc,
    filterGroup: group,
    filterValue: value,
    filterLabel: label ?? value,
    viewMode: viewMode,
  );

  LibraryQuery withoutFilter() =>
      LibraryQuery(sort: sort, desc: desc, viewMode: viewMode);

  Map<String, dynamic> toJson() => {
    'sort': sort.name,
    'desc': desc,
    'filterGroup': filterGroup?.name,
    'filterValue': filterValue,
    'filterLabel': filterLabel,
    'viewMode': viewMode.name,
  };

  @override
  bool operator ==(Object other) =>
      other is LibraryQuery &&
      other.sort == sort &&
      other.desc == desc &&
      other.filterGroup == filterGroup &&
      other.filterValue == filterValue &&
      other.viewMode == viewMode;

  @override
  int get hashCode =>
      Object.hash(sort, desc, filterGroup, filterValue, viewMode);
}

/// `GET /api/libraries/:id/filterdata`: the values each filter group offers.
class LibraryFilterData {
  const LibraryFilterData({
    this.authors = const [],
    this.series = const [],
    this.genres = const [],
    this.tags = const [],
    this.narrators = const [],
    this.languages = const [],
  });

  factory LibraryFilterData.fromJson(Map<String, dynamic> json) {
    List<({String id, String name})> idNames(Object? v) =>
        ((v as List<dynamic>?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map((m) => (id: m['id'].toString(), name: m['name'].toString()))
            .toList();
    List<String> strings(Object? v) =>
        ((v as List<dynamic>?) ?? const []).map((e) => e.toString()).toList();
    return LibraryFilterData(
      authors: idNames(json['authors']),
      series: idNames(json['series']),
      genres: strings(json['genres']),
      tags: strings(json['tags']),
      narrators: strings(json['narrators']),
      languages: strings(json['languages']),
    );
  }

  final List<({String id, String name})> authors;
  final List<({String id, String name})> series;
  final List<String> genres;
  final List<String> tags;
  final List<String> narrators;
  final List<String> languages;
}
