import 'dart:convert';

/// LIBRARY_PLAN.md L4: sort options, mapped to the server's `sort` values
/// (confirmed in `libraryItemsBookFilters.js`).
enum LibrarySort {
  title('media.metadata.title'),
  author('media.metadata.authorName'),
  addedAt('addedAt'),
  publishedYear('media.metadata.publishedYear'),
  duration('media.duration'),
  lastProgress('progress'),
  random('random');

  const LibrarySort(this.param);
  final String param;
}

enum LibraryViewMode { grid, list }

enum LibraryFilterGroup {
  genres,
  tags,
  authors,
  narrators,
  series,
  languages,
  progress,
  ebooks,
}

/// Progress filter values (the server compares the decoded string).
const progressFilterValues = [
  'in-progress',
  'finished',
  'not-started',
  'not-finished',
];

/// Ebook filter values (`ebooks.<base64>` in `libraryItemsBookFilters.js`).
const ebookFilterValues = ['ebook', 'no-ebook'];

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
    this.section = 'books',
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
      section: json['section']?.toString() ?? 'books',
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

  /// Which of Books/Authors/Collections/Playlists was last open (the
  /// `LibrarySection` name), so the library tab reopens where you left it.
  final String section;

  bool get hasFilter => filterGroup != null && filterValue != null;

  /// `<group>.<base64(value)>`, or null when unfiltered.
  String? get filterParam => hasFilter
      ? '${filterGroup!.name}.${base64.encode(utf8.encode(filterValue!))}'
      : null;

  LibraryQuery copyWith({
    LibrarySort? sort,
    bool? desc,
    LibraryViewMode? viewMode,
    String? section,
  }) => LibraryQuery(
    sort: sort ?? this.sort,
    desc: desc ?? this.desc,
    filterGroup: filterGroup,
    filterValue: filterValue,
    filterLabel: filterLabel,
    viewMode: viewMode ?? this.viewMode,
    section: section ?? this.section,
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
    section: section,
  );

  LibraryQuery withoutFilter() =>
      LibraryQuery(
        sort: sort,
        desc: desc,
        viewMode: viewMode,
        section: section,
      );

  Map<String, dynamic> toJson() => {
    'sort': sort.name,
    'desc': desc,
    'filterGroup': filterGroup?.name,
    'filterValue': filterValue,
    'filterLabel': filterLabel,
    'viewMode': viewMode.name,
    'section': section,
  };

  @override
  bool operator ==(Object other) =>
      other is LibraryQuery &&
      other.sort == sort &&
      other.desc == desc &&
      other.filterGroup == filterGroup &&
      other.filterValue == filterValue &&
      other.viewMode == viewMode &&
      other.section == section;

  @override
  int get hashCode =>
      Object.hash(sort, desc, filterGroup, filterValue, viewMode, section);
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
