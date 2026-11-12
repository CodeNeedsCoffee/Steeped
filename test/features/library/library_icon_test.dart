import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steeped/features/library/library_icon.dart';

void main() {
  test('every server icon name maps to its own icon', () {
    const names = [
      'database', 'audiobookshelf', 'books-1', 'books-2', 'book-1',
      'microphone-1', 'microphone-3', 'radio', 'podcast', 'rss', 'headphones',
      'music', 'file-picture', 'rocket', 'power', 'star', 'heart',
    ];
    for (final n in names) {
      expect(libraryIconFor(n), isNot(equals(null)));
    }
    expect(libraryIconFor('headphones'), Icons.headphones);
    expect(libraryIconFor('book-1'), Icons.book);
    expect(libraryIconFor('database'), Icons.storage);
  });

  test('an unknown name falls back to the database icon', () {
    expect(libraryIconFor('something-new'), Icons.storage);
    expect(libraryIconFor(''), Icons.storage);
  });
}
