import 'package:flutter_test/flutter_test.dart';
import 'package:steeped/features/linking/link_matching.dart';

LinkKey k(
  String id,
  String title, {
  String? author,
  String? asin,
  String? isbn,
  String? seq,
}) => LinkKey(
  id: id,
  title: title,
  author: author,
  asin: asin,
  isbn: isbn,
  seriesSequence: seq,
);

void main() {
  test('ASIN wins even when titles differ', () {
    expect(
      matchReason(
        k('a', 'Hobbit', asin: 'b0abc'),
        k('b', 'Other', asin: 'B0ABC'),
      ),
      LinkReason.asin,
    );
  });

  test('ISBN matches with hyphens ignored', () {
    expect(
      matchReason(
        k('a', 'X', isbn: '978-0-261-10221-7'),
        k('b', 'Y', isbn: '9780261102217'),
      ),
      LinkReason.isbn,
    );
  });

  test('falls back to author + normalised title', () {
    expect(
      matchReason(
        k('a', 'The Hobbit (Unabridged)', author: 'J.R.R. Tolkien'),
        k('b', 'Hobbit', author: 'j r r tolkien'),
      ),
      LinkReason.authorTitle,
    );
  });

  test('author order does not matter, one shared author is enough', () {
    expect(
      matchReason(
        k('a', 'Good Omens', author: 'Terry Pratchett, Neil Gaiman'),
        k('b', 'Good Omens', author: 'Neil Gaiman'),
      ),
      LinkReason.authorTitle,
    );
  });

  test('same title by a different author does not match', () {
    expect(
      matchReason(
        k('a', 'Dune', author: 'Frank Herbert'),
        k('b', 'Dune', author: 'Someone Else'),
      ),
      isNull,
    );
  });

  test('missing author does not match on title alone', () {
    expect(matchReason(k('a', 'Dune'), k('b', 'Dune')), isNull);
  });

  test('different series sequence breaks a shared title', () {
    expect(
      matchReason(
        k('a', 'Origins', author: 'X', seq: '1'),
        k('b', 'Origins', author: 'X', seq: '2'),
      ),
      isNull,
    );
  });

  test(
    'candidates are ordered ASIN, ISBN, then author + title; self excluded',
    () {
      final src = k(
        's',
        'Dune',
        author: 'Frank Herbert',
        asin: 'A1',
        isbn: 'I1',
      );
      final out = findLinkCandidates(src, [
        k('t', 'Dune', author: 'Frank Herbert'),
        k('i', 'Zzz', isbn: 'I1'),
        k('a', 'Qqq', asin: 'A1'),
        k('s', 'Dune', author: 'Frank Herbert', asin: 'A1'),
        k('n', 'Nope', author: 'Nobody'),
      ]);
      expect([for (final c in out) c.key.id], ['a', 'i', 't']);
    },
  );
}
