/// `GET /api/libraries` → `{ libraries: Library[] }`. See
/// `~/Code/audiobookshelf/server/models/Library.js` (`toOldJSON`).
class Library {
  const Library({
    required this.id,
    required this.name,
    required this.mediaType,
    required this.icon,
    required this.displayOrder,
  });

  factory Library.fromJson(Map<String, dynamic> json) {
    return Library(
      id: json['id'] as String,
      name: json['name'] as String,
      mediaType: json['mediaType'] as String? ?? 'book',
      icon: json['icon'] as String? ?? 'database',
      displayOrder: json['displayOrder'] as int? ?? 0,
    );
  }

  final String id;
  final String name;
  final String mediaType; // 'book' | 'podcast'
  final String icon;
  final int displayOrder;

  bool get isPodcastLibrary => mediaType == 'podcast';
}
