import 'package:flutter/material.dart';

/// The icon names an Audiobookshelf admin can give a library (the server's
/// `libraryIcons` list). The web UI draws them from its own icon font, so
/// each maps to the nearest Material icon; unknown names fall back to the
/// `database` look.
IconData libraryIconFor(String name) => switch (name) {
  'audiobookshelf' => Icons.auto_stories,
  'books-1' || 'books-2' => Icons.library_books,
  'book-1' => Icons.book,
  'microphone-1' || 'microphone-3' => Icons.mic,
  'radio' => Icons.radio,
  'podcast' => Icons.podcasts,
  'rss' => Icons.rss_feed,
  'headphones' => Icons.headphones,
  'music' => Icons.music_note,
  'file-picture' => Icons.image,
  'rocket' => Icons.rocket_launch,
  'power' => Icons.power_settings_new,
  'star' => Icons.star,
  'heart' => Icons.favorite,
  _ => Icons.storage,
};
