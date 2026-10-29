import '../../models/library_browse.dart';
import '../../models/library_item.dart';

/// QOL_PLAN D4: an author's books in reading order: each series in turn
/// (books by sequence, unnumbered last), then standalone books by title.
/// A book in several series appears once, under the first.
List<LibraryItem> authorBooksInReadingOrder(Author author) {
  final seen = <String>{};
  final ordered = <LibraryItem>[];

  final series = [...author.series]
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  for (final s in series) {
    final books = [...s.books]
      ..sort((a, b) => compareSequence(a.seriesSequence, b.seriesSequence));
    for (final b in books) {
      if (seen.add(b.id)) ordered.add(b);
    }
  }

  final standalone = [
    for (final b in author.books)
      if (!seen.contains(b.id)) b,
  ]..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  return [...ordered, ...standalone];
}

/// Numeric-aware sequence comparison ("2" < "10", "1.5" between 1 and 2);
/// missing or non-numeric sequences sort last.
int compareSequence(String? a, String? b) {
  final x = double.tryParse(a ?? '');
  final y = double.tryParse(b ?? '');
  if (x == null && y == null) return (a ?? '').compareTo(b ?? '');
  if (x == null) return 1;
  if (y == null) return -1;
  return x.compareTo(y);
}
