/// `user.permissions` from the login/refresh response, plus the two
/// top-level sibling fields (`librariesAccessible`, `itemTagsSelected`) that
/// the server hoists out of the permissions sub-object. See
/// `~/Code/audiobookshelf/server/models/User.js` (`toOldJSONForBrowser`,
/// `checkCanAccessLibrary`, `checkCanAccessLibraryItemWithTags`).
class UserPermissions {
  const UserPermissions({
    required this.download,
    required this.update,
    required this.delete,
    required this.upload,
    required this.createEreader,
    required this.accessAllLibraries,
    required this.accessAllTags,
    required this.accessExplicitContent,
    required this.selectedTagsNotAccessible,
    required this.librariesAccessible,
    required this.itemTagsSelected,
  });

  factory UserPermissions.fromJson(
    Map<String, dynamic> permissionsJson, {
    List<String> librariesAccessible = const [],
    List<String> itemTagsSelected = const [],
  }) {
    return UserPermissions(
      download: permissionsJson['download'] as bool? ?? true,
      update: permissionsJson['update'] as bool? ?? false,
      delete: permissionsJson['delete'] as bool? ?? false,
      upload: permissionsJson['upload'] as bool? ?? false,
      createEreader: permissionsJson['createEreader'] as bool? ?? false,
      accessAllLibraries: permissionsJson['accessAllLibraries'] as bool? ?? true,
      accessAllTags: permissionsJson['accessAllTags'] as bool? ?? true,
      accessExplicitContent:
          permissionsJson['accessExplicitContent'] as bool? ?? false,
      selectedTagsNotAccessible:
          permissionsJson['selectedTagsNotAccessible'] as bool? ?? false,
      librariesAccessible: librariesAccessible,
      itemTagsSelected: itemTagsSelected,
    );
  }

  final bool download;
  final bool update;
  final bool delete;
  final bool upload;
  final bool createEreader;
  final bool accessAllLibraries;
  final bool accessAllTags;
  final bool accessExplicitContent;
  final bool selectedTagsNotAccessible;
  final List<String> librariesAccessible;
  final List<String> itemTagsSelected;

  bool canAccessLibrary(String libraryId) {
    return accessAllLibraries || librariesAccessible.contains(libraryId);
  }

  bool canAccessLibraryItemWithTags(List<String> tags) {
    if (accessAllTags) return true;
    if (selectedTagsNotAccessible) {
      // itemTagsSelected acts as a denylist.
      return tags.isEmpty || tags.every((t) => !itemTagsSelected.contains(t));
    }
    // itemTagsSelected acts as an allowlist.
    return tags.isNotEmpty && itemTagsSelected.any(tags.contains);
  }
}
