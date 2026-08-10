import 'bookshelf_skin.dart';
import 'glass_modern_skin.dart';
import 'skin.dart';

/// PLAN.md Phase 2.4: every skin the switcher can offer. Glass Modern is
/// first/default per the project's stated primary aesthetic (README/PLAN's
/// "glass/modern look and a user-selectable skin").
const List<Skin> availableSkins = [GlassModernSkin(), BookshelfSkin()];

Skin skinById(SkinId id) {
  return availableSkins.firstWhere((s) => s.id == id);
}

Skin skinByName(String name) {
  final id = SkinId.values.asNameMap()[name];
  return id == null ? availableSkins.first : skinById(id);
}
