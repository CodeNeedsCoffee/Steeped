import 'package:flutter_test/flutter_test.dart';
import 'package:steeped/models/library.dart';

void main() {
  group('Library', () {
    test('toJson/fromJson round-trips every field', () {
      const library = Library(
        id: 'lib-1',
        name: 'Audio Books',
        mediaType: 'podcast',
        icon: 'podcast',
        displayOrder: 3,
      );

      final restored = Library.fromJson(library.toJson());

      expect(restored.id, library.id);
      expect(restored.name, library.name);
      expect(restored.mediaType, library.mediaType);
      expect(restored.icon, library.icon);
      expect(restored.displayOrder, library.displayOrder);
      expect(restored.isPodcastLibrary, isTrue);
    });
  });
}
