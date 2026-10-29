import '../core/theme/skin.dart';
import '../features/library/library_browse_tab.dart';
import '../models/library_query.dart';
import 'gen/app_localizations.dart';

/// Localized names for the app's enums, so the enums themselves hold no
/// user-facing English.
extension LibrarySortL10n on LibrarySort {
  String localized(AppLocalizations l) => switch (this) {
    LibrarySort.title => l.sortTitle,
    LibrarySort.author => l.sortAuthor,
    LibrarySort.addedAt => l.sortDateAdded,
    LibrarySort.publishedYear => l.sortPublishedYear,
    LibrarySort.duration => l.sortDuration,
    LibrarySort.lastProgress => l.sortLastPlayed,
    LibrarySort.random => l.sortRandom,
  };
}

extension LibraryFilterGroupL10n on LibraryFilterGroup {
  String localized(AppLocalizations l) => switch (this) {
    LibraryFilterGroup.genres => l.filterGenre,
    LibraryFilterGroup.tags => l.filterTag,
    LibraryFilterGroup.authors => l.filterAuthor,
    LibraryFilterGroup.narrators => l.filterNarrator,
    LibraryFilterGroup.series => l.filterSeries,
    LibraryFilterGroup.languages => l.filterLanguage,
    LibraryFilterGroup.progress => l.filterProgress,
    LibraryFilterGroup.ebooks => l.filterEbook,
  };
}

/// Label for a progress-filter value key (`progressFilterValues`).
String progressFilterLabel(AppLocalizations l, String value) => switch (value) {
  'in-progress' => l.progressInProgress,
  'finished' => l.progressFinished,
  'not-started' => l.progressNotStarted,
  'not-finished' => l.progressNotFinished,
  _ => value,
};

/// Label for an ebook-filter value key (`ebookFilterValues`).
String ebookFilterLabel(AppLocalizations l, String value) => switch (value) {
  'ebook' => l.ebookHas,
  'no-ebook' => l.ebookNone,
  _ => value,
};

extension LibrarySectionL10n on LibrarySection {
  String localized(AppLocalizations l) => switch (this) {
    LibrarySection.books => l.sectionBooks,
    LibrarySection.authors => l.sectionAuthors,
    LibrarySection.collections => l.sectionCollections,
    LibrarySection.playlists => l.sectionPlaylists,
  };
}

extension ThemeVariantL10n on ThemeVariant {
  String localized(AppLocalizations l) => switch (this) {
    ThemeVariant.system => l.themeSystem,
    ThemeVariant.light => l.themeLight,
    ThemeVariant.dark => l.themeDark,
    ThemeVariant.black => l.themeBlack,
  };
}

extension SkinIdL10n on SkinId {
  String localized(AppLocalizations l) => switch (this) {
    SkinId.glassModern => l.skinGlassModernName,
    SkinId.bookshelf => l.skinBookshelfName,
  };

  String description(AppLocalizations l) => switch (this) {
    SkinId.glassModern => l.skinGlassModernDescription,
    SkinId.bookshelf => l.skinBookshelfDescription,
  };
}
