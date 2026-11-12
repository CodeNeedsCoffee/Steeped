import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// The application name.
  ///
  /// In en, this message translates to:
  /// **'Steeped'**
  String get appName;

  /// No description provided for @connectToServer.
  ///
  /// In en, this message translates to:
  /// **'Connect to Server'**
  String get connectToServer;

  /// No description provided for @enterYourAudiobookshelfServerAddress.
  ///
  /// In en, this message translates to:
  /// **'Enter your Audiobookshelf server address'**
  String get enterYourAudiobookshelfServerAddress;

  /// No description provided for @serverAddress.
  ///
  /// In en, this message translates to:
  /// **'Server address'**
  String get serverAddress;

  /// No description provided for @audiobookshelfExampleCom.
  ///
  /// In en, this message translates to:
  /// **'audiobookshelf.example.com'**
  String get audiobookshelfExampleCom;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @logIn.
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get logIn;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @deleteAllDownloadsTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete all downloads?'**
  String get deleteAllDownloadsTitle;

  /// No description provided for @thisRemovesEveryDownloadedBook.
  ///
  /// In en, this message translates to:
  /// **'This removes every downloaded book and episode from this device. They remain on the server and can be downloaded again.'**
  String get thisRemovesEveryDownloadedBook;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @deleteAll.
  ///
  /// In en, this message translates to:
  /// **'Delete All'**
  String get deleteAll;

  /// No description provided for @downloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get downloads;

  /// No description provided for @deleteAllDownloadsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete all downloads'**
  String get deleteAllDownloadsTooltip;

  /// No description provided for @failedToLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load: {error}'**
  String failedToLoad(Object error);

  /// No description provided for @noDownloadsYet.
  ///
  /// In en, this message translates to:
  /// **'No downloads yet.'**
  String get noDownloadsYet;

  /// No description provided for @deleteDownload.
  ///
  /// In en, this message translates to:
  /// **'Delete download'**
  String get deleteDownload;

  /// No description provided for @storageIsRunningLowDelete.
  ///
  /// In en, this message translates to:
  /// **'Storage is running low. Delete a download to free up space.'**
  String get storageIsRunningLowDelete;

  /// No description provided for @tableOfContents.
  ///
  /// In en, this message translates to:
  /// **'Table of Contents'**
  String get tableOfContents;

  /// No description provided for @readingSettingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Reading settings'**
  String get readingSettingsTooltip;

  /// No description provided for @downloadingBook.
  ///
  /// In en, this message translates to:
  /// **'Downloading book…'**
  String get downloadingBook;

  /// No description provided for @readingSettings.
  ///
  /// In en, this message translates to:
  /// **'Reading Settings'**
  String get readingSettings;

  /// No description provided for @font.
  ///
  /// In en, this message translates to:
  /// **'Font'**
  String get font;

  /// No description provided for @sans.
  ///
  /// In en, this message translates to:
  /// **'Sans'**
  String get sans;

  /// No description provided for @serif.
  ///
  /// In en, this message translates to:
  /// **'Serif'**
  String get serif;

  /// No description provided for @bold.
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get bold;

  /// No description provided for @fontSize.
  ///
  /// In en, this message translates to:
  /// **'Font size'**
  String get fontSize;

  /// No description provided for @lineSpacing.
  ///
  /// In en, this message translates to:
  /// **'Line spacing'**
  String get lineSpacing;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @black.
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get black;

  /// No description provided for @downloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading…'**
  String get downloading;

  /// No description provided for @noLibrariesOnThisServer.
  ///
  /// In en, this message translates to:
  /// **'No libraries on this server.'**
  String get noLibrariesOnThisServer;

  /// No description provided for @failedToLoadLibraries.
  ///
  /// In en, this message translates to:
  /// **'Failed to load libraries: {error}'**
  String failedToLoadLibraries(Object error);

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @viewDownloads.
  ///
  /// In en, this message translates to:
  /// **'View Downloads'**
  String get viewDownloads;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @latestEpisodes.
  ///
  /// In en, this message translates to:
  /// **'Latest Episodes'**
  String get latestEpisodes;

  /// No description provided for @failedToLoadHomeShelves.
  ///
  /// In en, this message translates to:
  /// **'Failed to load home shelves: {error}'**
  String failedToLoadHomeShelves(Object error);

  /// No description provided for @nothingToShowYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing to show yet.'**
  String get nothingToShowYet;

  /// No description provided for @failedToLoadSeries.
  ///
  /// In en, this message translates to:
  /// **'Failed to load series: {error}'**
  String failedToLoadSeries(Object error);

  /// No description provided for @noSeriesInThisLibrary.
  ///
  /// In en, this message translates to:
  /// **'No series in this library.'**
  String get noSeriesInThisLibrary;

  /// No description provided for @bookCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 book} other{{count} books}}'**
  String bookCount(num count);

  /// No description provided for @canTReachTheServer.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach the server. Showing downloaded content.'**
  String get canTReachTheServer;

  /// No description provided for @continueListening.
  ///
  /// In en, this message translates to:
  /// **'Continue Listening'**
  String get continueListening;

  /// No description provided for @noDownloadedContentYet.
  ///
  /// In en, this message translates to:
  /// **'No downloaded content yet.'**
  String get noDownloadedContentYet;

  /// No description provided for @browsingNeedsAConnection.
  ///
  /// In en, this message translates to:
  /// **'{label} browsing needs a connection.'**
  String browsingNeedsAConnection(Object label);

  /// No description provided for @moreActions.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get moreActions;

  /// No description provided for @discardProgressButton.
  ///
  /// In en, this message translates to:
  /// **'Discard progress'**
  String get discardProgressButton;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @read.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get read;

  /// No description provided for @readAgain.
  ///
  /// In en, this message translates to:
  /// **'Read again'**
  String get readAgain;

  /// No description provided for @narratedBy.
  ///
  /// In en, this message translates to:
  /// **'Narrated by {join}'**
  String narratedBy(Object join);

  /// No description provided for @isnTSupportedYetNo.
  ///
  /// In en, this message translates to:
  /// **'.{format} isn\'t supported yet — no pure-Dart RAR decoder exists for CBR.'**
  String isnTSupportedYetNo(Object format);

  /// No description provided for @downloadSeries.
  ///
  /// In en, this message translates to:
  /// **'Download series: {name}'**
  String downloadSeries(Object name);

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @downloaded.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get downloaded;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @couldNotLoadPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Could not load playlists: {e}'**
  String couldNotLoadPlaylists(Object e);

  /// No description provided for @addToPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Add to playlist'**
  String get addToPlaylist;

  /// No description provided for @newPlaylistEllipsis.
  ///
  /// In en, this message translates to:
  /// **'New playlist…'**
  String get newPlaylistEllipsis;

  /// No description provided for @addedTo.
  ///
  /// In en, this message translates to:
  /// **'Added to \"{name}\"'**
  String addedTo(Object name);

  /// No description provided for @couldNotCreatePlaylist.
  ///
  /// In en, this message translates to:
  /// **'Could not create playlist: {e}'**
  String couldNotCreatePlaylist(Object e);

  /// No description provided for @itemCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String itemCount(num count);

  /// No description provided for @playlistUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Playlist update failed: {e}'**
  String playlistUpdateFailed(Object e);

  /// No description provided for @couldNotLoadCollections.
  ///
  /// In en, this message translates to:
  /// **'Could not load collections: {e}'**
  String couldNotLoadCollections(Object e);

  /// No description provided for @addToCollection.
  ///
  /// In en, this message translates to:
  /// **'Add to collection'**
  String get addToCollection;

  /// No description provided for @newCollectionEllipsis.
  ///
  /// In en, this message translates to:
  /// **'New collection…'**
  String get newCollectionEllipsis;

  /// No description provided for @couldNotCreateCollection.
  ///
  /// In en, this message translates to:
  /// **'Could not create collection: {e}'**
  String couldNotCreateCollection(Object e);

  /// No description provided for @books.
  ///
  /// In en, this message translates to:
  /// **'{count} books'**
  String books(Object count);

  /// No description provided for @collectionUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Collection update failed: {e}'**
  String collectionUpdateFailed(Object e);

  /// No description provided for @goToAuthor.
  ///
  /// In en, this message translates to:
  /// **'Go to author'**
  String get goToAuthor;

  /// No description provided for @goToSeries.
  ///
  /// In en, this message translates to:
  /// **'Go to series'**
  String get goToSeries;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// No description provided for @downloadStarted.
  ///
  /// In en, this message translates to:
  /// **'Download started'**
  String get downloadStarted;

  /// No description provided for @downloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed: {e}'**
  String downloadFailed(Object e);

  /// No description provided for @markFinished.
  ///
  /// In en, this message translates to:
  /// **'Mark finished'**
  String get markFinished;

  /// No description provided for @markNotFinished.
  ///
  /// In en, this message translates to:
  /// **'Mark not finished'**
  String get markNotFinished;

  /// No description provided for @couldNotUpdate.
  ///
  /// In en, this message translates to:
  /// **'Could not update: {e}'**
  String couldNotUpdate(Object e);

  /// No description provided for @notAvailableForThisItem.
  ///
  /// In en, this message translates to:
  /// **'Not available for this item'**
  String get notAvailableForThisItem;

  /// No description provided for @couldNotOpen.
  ///
  /// In en, this message translates to:
  /// **'Could not open: {e}'**
  String couldNotOpen(Object e);

  /// No description provided for @failedToLoadAuthors.
  ///
  /// In en, this message translates to:
  /// **'Failed to load authors: {e}'**
  String failedToLoadAuthors(Object e);

  /// No description provided for @noAuthorsInThisLibrary.
  ///
  /// In en, this message translates to:
  /// **'No authors in this library.'**
  String get noAuthorsInThisLibrary;

  /// No description provided for @failedToLoadCollections.
  ///
  /// In en, this message translates to:
  /// **'Failed to load collections: {e}'**
  String failedToLoadCollections(Object e);

  /// No description provided for @newCollection.
  ///
  /// In en, this message translates to:
  /// **'New collection'**
  String get newCollection;

  /// No description provided for @noCollectionsYet.
  ///
  /// In en, this message translates to:
  /// **'No collections yet.'**
  String get noCollectionsYet;

  /// No description provided for @bookCountDuration.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 book} other{{count} books}} · {duration}'**
  String bookCountDuration(num count, String duration);

  /// No description provided for @failedToLoadPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Failed to load playlists: {e}'**
  String failedToLoadPlaylists(Object e);

  /// No description provided for @newPlaylist.
  ///
  /// In en, this message translates to:
  /// **'New playlist'**
  String get newPlaylist;

  /// No description provided for @noPlaylistsYet.
  ///
  /// In en, this message translates to:
  /// **'No playlists yet.'**
  String get noPlaylistsYet;

  /// No description provided for @itemCountDuration.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}} · {duration}'**
  String itemCountDuration(num count, String duration);

  /// No description provided for @failedToLoadAuthor.
  ///
  /// In en, this message translates to:
  /// **'Failed to load author: {e}'**
  String failedToLoadAuthor(Object e);

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @failedToLoadCollection.
  ///
  /// In en, this message translates to:
  /// **'Failed to load collection: {e}'**
  String failedToLoadCollection(Object e);

  /// No description provided for @playAll.
  ///
  /// In en, this message translates to:
  /// **'Play all'**
  String get playAll;

  /// No description provided for @downloadAll.
  ///
  /// In en, this message translates to:
  /// **'Download all'**
  String get downloadAll;

  /// No description provided for @queuedDownloads.
  ///
  /// In en, this message translates to:
  /// **'Queued {n} downloads'**
  String queuedDownloads(Object n);

  /// No description provided for @thisCollectionIsEmpty.
  ///
  /// In en, this message translates to:
  /// **'This collection is empty.'**
  String get thisCollectionIsEmpty;

  /// No description provided for @removeFromCollection.
  ///
  /// In en, this message translates to:
  /// **'Remove from collection'**
  String get removeFromCollection;

  /// No description provided for @couldNotReorder.
  ///
  /// In en, this message translates to:
  /// **'Could not reorder: {e}'**
  String couldNotReorder(Object e);

  /// No description provided for @failedToLoadPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Failed to load playlist: {e}'**
  String failedToLoadPlaylist(Object e);

  /// No description provided for @thisPlaylistIsEmpty.
  ///
  /// In en, this message translates to:
  /// **'This playlist is empty.'**
  String get thisPlaylistIsEmpty;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @libraryLabel.
  ///
  /// In en, this message translates to:
  /// **'Library ({total})'**
  String libraryLabel(Object total);

  /// No description provided for @sort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sort;

  /// No description provided for @filter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get clearAll;

  /// No description provided for @couldNotLoadFilters.
  ///
  /// In en, this message translates to:
  /// **'Could not load filters: {e}'**
  String couldNotLoadFilters(Object e);

  /// No description provided for @filterBy.
  ///
  /// In en, this message translates to:
  /// **'Filter by'**
  String get filterBy;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @nothingToFilterOn.
  ///
  /// In en, this message translates to:
  /// **'Nothing to filter on.'**
  String get nothingToFilterOn;

  /// No description provided for @searchBooksSeriesAuthors.
  ///
  /// In en, this message translates to:
  /// **'Search books, series, authors…'**
  String get searchBooksSeriesAuthors;

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No results.'**
  String get noResults;

  /// No description provided for @searchFailed.
  ///
  /// In en, this message translates to:
  /// **'Search failed: {error}'**
  String searchFailed(Object error);

  /// No description provided for @searchThisLibrary.
  ///
  /// In en, this message translates to:
  /// **'Search this library.'**
  String get searchThisLibrary;

  /// No description provided for @recentSearches.
  ///
  /// In en, this message translates to:
  /// **'Recent searches'**
  String get recentSearches;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @seriesUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Series unavailable.'**
  String get seriesUnavailable;

  /// No description provided for @localMedia.
  ///
  /// In en, this message translates to:
  /// **'Local Media'**
  String get localMedia;

  /// No description provided for @importAFile.
  ///
  /// In en, this message translates to:
  /// **'Import a file'**
  String get importAFile;

  /// No description provided for @imported.
  ///
  /// In en, this message translates to:
  /// **'Imported \"{title}\"'**
  String imported(Object title);

  /// No description provided for @noLocalMediaYetTap.
  ///
  /// In en, this message translates to:
  /// **'No local media yet. Tap + to import an audio file from this device — these never touch the server.'**
  String get noLocalMediaYetTap;

  /// No description provided for @discardProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard progress?'**
  String get discardProgressTitle;

  /// No description provided for @allListeningProgressForWill.
  ///
  /// In en, this message translates to:
  /// **'All listening progress for \"{title}\" will be removed. The book itself is not affected.'**
  String allListeningProgressForWill(Object title);

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @progressDiscarded.
  ///
  /// In en, this message translates to:
  /// **'Progress discarded'**
  String get progressDiscarded;

  /// No description provided for @couldNotDiscardProgress.
  ///
  /// In en, this message translates to:
  /// **'Could not discard progress: {e}'**
  String couldNotDiscardProgress(Object e);

  /// No description provided for @expand.
  ///
  /// In en, this message translates to:
  /// **'Expand'**
  String get expand;

  /// No description provided for @rewindSeconds.
  ///
  /// In en, this message translates to:
  /// **'Rewind {jumpBackSeconds} seconds'**
  String rewindSeconds(Object jumpBackSeconds);

  /// No description provided for @forwardSeconds.
  ///
  /// In en, this message translates to:
  /// **'Forward {jumpForwardSeconds} seconds'**
  String forwardSeconds(Object jumpForwardSeconds);

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @stopPlayback.
  ///
  /// In en, this message translates to:
  /// **'Stop and close player'**
  String get stopPlayback;

  /// No description provided for @queue.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get queue;

  /// No description provided for @timeDisplayTooltip.
  ///
  /// In en, this message translates to:
  /// **'Time display'**
  String get timeDisplayTooltip;

  /// No description provided for @sleepTimer.
  ///
  /// In en, this message translates to:
  /// **'Sleep Timer'**
  String get sleepTimer;

  /// No description provided for @timeDisplayMenu.
  ///
  /// In en, this message translates to:
  /// **'Time Display'**
  String get timeDisplayMenu;

  /// No description provided for @markAsFinished.
  ///
  /// In en, this message translates to:
  /// **'Mark as Finished'**
  String get markAsFinished;

  /// No description provided for @markAsNotFinished.
  ///
  /// In en, this message translates to:
  /// **'Mark as Not Finished'**
  String get markAsNotFinished;

  /// No description provided for @discardProgressMenu.
  ///
  /// In en, this message translates to:
  /// **'Discard Progress'**
  String get discardProgressMenu;

  /// No description provided for @bookmarks.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get bookmarks;

  /// No description provided for @chapters.
  ///
  /// In en, this message translates to:
  /// **'Chapters'**
  String get chapters;

  /// No description provided for @tracks.
  ///
  /// In en, this message translates to:
  /// **'Tracks'**
  String get tracks;

  /// No description provided for @minutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} minutes'**
  String minutes(Object minutes);

  /// No description provided for @endOfChapter.
  ///
  /// In en, this message translates to:
  /// **'End of chapter'**
  String get endOfChapter;

  /// No description provided for @cancelTimer.
  ///
  /// In en, this message translates to:
  /// **'Cancel timer'**
  String get cancelTimer;

  /// No description provided for @queueFinished.
  ///
  /// In en, this message translates to:
  /// **'Queue finished.'**
  String get queueFinished;

  /// No description provided for @queueNamed.
  ///
  /// In en, this message translates to:
  /// **'Queue: {name}'**
  String queueNamed(Object name);

  /// No description provided for @removeFromQueue.
  ///
  /// In en, this message translates to:
  /// **'Remove from queue'**
  String get removeFromQueue;

  /// No description provided for @noBookmarksYet.
  ///
  /// In en, this message translates to:
  /// **'No bookmarks yet'**
  String get noBookmarksYet;

  /// No description provided for @deleteBookmarkTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete bookmark'**
  String get deleteBookmarkTooltip;

  /// No description provided for @addBookmarkAtCurrentPosition.
  ///
  /// In en, this message translates to:
  /// **'Add bookmark at current position'**
  String get addBookmarkAtCurrentPosition;

  /// No description provided for @addBookmark.
  ///
  /// In en, this message translates to:
  /// **'Add Bookmark'**
  String get addBookmark;

  /// No description provided for @note.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get note;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @failedToAddBookmark.
  ///
  /// In en, this message translates to:
  /// **'Failed to add bookmark'**
  String get failedToAddBookmark;

  /// No description provided for @deleteBookmarkTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete bookmark?'**
  String get deleteBookmarkTitle;

  /// No description provided for @thisRemovesFromTheServer.
  ///
  /// In en, this message translates to:
  /// **'This removes \"{title}\" from the server.'**
  String thisRemovesFromTheServer(Object title);

  /// No description provided for @failedToDeleteBookmark.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete bookmark'**
  String get failedToDeleteBookmark;

  /// No description provided for @playbackSpeed.
  ///
  /// In en, this message translates to:
  /// **'Playback Speed'**
  String get playbackSpeed;

  /// No description provided for @exactSpeed.
  ///
  /// In en, this message translates to:
  /// **'Exact speed'**
  String get exactSpeed;

  /// No description provided for @setLabel.
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get setLabel;

  /// No description provided for @resetTo1x.
  ///
  /// In en, this message translates to:
  /// **'Reset to 1x'**
  String get resetTo1x;

  /// No description provided for @restart.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get restart;

  /// No description provided for @min.
  ///
  /// In en, this message translates to:
  /// **'+{sleepExtendMinutes} min'**
  String min(Object sleepExtendMinutes);

  /// No description provided for @dismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// No description provided for @syncWaitingTooltip.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 progress update} other{{count} progress updates}} waiting to sync — tap to retry'**
  String syncWaitingTooltip(num count);

  /// No description provided for @chapter.
  ///
  /// In en, this message translates to:
  /// **'Chapter'**
  String get chapter;

  /// No description provided for @book.
  ///
  /// In en, this message translates to:
  /// **'Book'**
  String get book;

  /// No description provided for @noEpisodesYet.
  ///
  /// In en, this message translates to:
  /// **'No episodes yet.'**
  String get noEpisodesYet;

  /// No description provided for @downloadEpisode.
  ///
  /// In en, this message translates to:
  /// **'Download episode'**
  String get downloadEpisode;

  /// No description provided for @deleteDownloadedEpisode.
  ///
  /// In en, this message translates to:
  /// **'Delete downloaded episode'**
  String get deleteDownloadedEpisode;

  /// No description provided for @noRecentEpisodes.
  ///
  /// In en, this message translates to:
  /// **'No recent episodes.'**
  String get noRecentEpisodes;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @server.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get server;

  /// No description provided for @downloadsAllowed.
  ///
  /// In en, this message translates to:
  /// **'Downloads allowed'**
  String get downloadsAllowed;

  /// No description provided for @uploadsAllowed.
  ///
  /// In en, this message translates to:
  /// **'Uploads allowed'**
  String get uploadsAllowed;

  /// No description provided for @updatesAllowed.
  ///
  /// In en, this message translates to:
  /// **'Updates allowed'**
  String get updatesAllowed;

  /// No description provided for @deletesAllowed.
  ///
  /// In en, this message translates to:
  /// **'Deletes allowed'**
  String get deletesAllowed;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePassword;

  /// No description provided for @logOut.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get logOut;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @skin.
  ///
  /// In en, this message translates to:
  /// **'Skin'**
  String get skin;

  /// No description provided for @passwordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password changed.'**
  String get passwordChanged;

  /// No description provided for @currentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get currentPassword;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPassword;

  /// No description provided for @atLeastCharacters.
  ///
  /// In en, this message translates to:
  /// **'At least {minPasswordLength} characters'**
  String atLeastCharacters(Object minPasswordLength);

  /// No description provided for @confirmNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get confirmNewPassword;

  /// No description provided for @changingYourPasswordSignsYou.
  ///
  /// In en, this message translates to:
  /// **'Changing your password signs you out on your other devices. This one stays signed in.'**
  String get changingYourPasswordSignsYou;

  /// No description provided for @logs.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get logs;

  /// No description provided for @clearLogs.
  ///
  /// In en, this message translates to:
  /// **'Clear logs'**
  String get clearLogs;

  /// No description provided for @noLogEntriesYet.
  ///
  /// In en, this message translates to:
  /// **'No log entries yet.'**
  String get noLogEntriesYet;

  /// No description provided for @stats.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get stats;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @rssFeeds.
  ///
  /// In en, this message translates to:
  /// **'RSS Feeds'**
  String get rssFeeds;

  /// No description provided for @adminNotYetImplemented.
  ///
  /// In en, this message translates to:
  /// **'Admin tools will be added later'**
  String get adminNotYetImplemented;

  /// No description provided for @jumpBack.
  ///
  /// In en, this message translates to:
  /// **'Jump back'**
  String get jumpBack;

  /// No description provided for @jumpForward.
  ///
  /// In en, this message translates to:
  /// **'Jump forward'**
  String get jumpForward;

  /// No description provided for @allowSeekingOnLockScreen.
  ///
  /// In en, this message translates to:
  /// **'Allow seeking on lock-screen controls'**
  String get allowSeekingOnLockScreen;

  /// No description provided for @showADraggableProgressBar.
  ///
  /// In en, this message translates to:
  /// **'Show a draggable progress bar in the notification and lock screen'**
  String get showADraggableProgressBar;

  /// No description provided for @autoRewindOnResume.
  ///
  /// In en, this message translates to:
  /// **'Auto-rewind on resume'**
  String get autoRewindOnResume;

  /// No description provided for @stepBackALittleWhen.
  ///
  /// In en, this message translates to:
  /// **'Step back a little when you press play'**
  String get stepBackALittleWhen;

  /// No description provided for @rewindFurtherAfterLongPauses.
  ///
  /// In en, this message translates to:
  /// **'Rewind further after long pauses'**
  String get rewindFurtherAfterLongPauses;

  /// No description provided for @autoRewindScaleHint.
  ///
  /// In en, this message translates to:
  /// **'2x after 5 minutes, 3x after an hour'**
  String get autoRewindScaleHint;

  /// No description provided for @scaleElapsedTimeBySpeed.
  ///
  /// In en, this message translates to:
  /// **'Scale elapsed time by speed'**
  String get scaleElapsedTimeBySpeed;

  /// No description provided for @showNowPlayingSTime.
  ///
  /// In en, this message translates to:
  /// **'Show Now Playing\'s time as real-world minutes at your current speed'**
  String get showNowPlayingSTime;

  /// No description provided for @showTracksTab.
  ///
  /// In en, this message translates to:
  /// **'Show Tracks tab'**
  String get showTracksTab;

  /// No description provided for @onNowPlayingAddA.
  ///
  /// In en, this message translates to:
  /// **'On Now Playing, add a toggle to switch between chapters and a multi-file book\'s raw audio-file tracks'**
  String get onNowPlayingAddA;

  /// No description provided for @defaultDuration.
  ///
  /// In en, this message translates to:
  /// **'Default duration'**
  String get defaultDuration;

  /// No description provided for @extendBy.
  ///
  /// In en, this message translates to:
  /// **'Extend by'**
  String get extendBy;

  /// No description provided for @fadeOutBeforePausing.
  ///
  /// In en, this message translates to:
  /// **'Fade out before pausing'**
  String get fadeOutBeforePausing;

  /// No description provided for @fadeLength.
  ///
  /// In en, this message translates to:
  /// **'Fade length'**
  String get fadeLength;

  /// No description provided for @sleepChimeBeforePausing.
  ///
  /// In en, this message translates to:
  /// **'Chime 30 seconds before pausing'**
  String get sleepChimeBeforePausing;

  /// No description provided for @startAutomaticallyAtNight.
  ///
  /// In en, this message translates to:
  /// **'Start automatically at night'**
  String get startAutomaticallyAtNight;

  /// No description provided for @beginTheDefaultTimerWhen.
  ///
  /// In en, this message translates to:
  /// **'Begin the default timer when playback starts inside the window'**
  String get beginTheDefaultTimerWhen;

  /// No description provided for @treatMeteredWiFiLike.
  ///
  /// In en, this message translates to:
  /// **'Treat metered Wi-Fi like cellular'**
  String get treatMeteredWiFiLike;

  /// No description provided for @applyTheChoicesAboveTo.
  ///
  /// In en, this message translates to:
  /// **'Apply the choices above to metered Wi-Fi, such as a phone hotspot'**
  String get applyTheChoicesAboveTo;

  /// No description provided for @rememberLibrarySection.
  ///
  /// In en, this message translates to:
  /// **'Remember library section'**
  String get rememberLibrarySection;

  /// No description provided for @reopenOnBooksAuthorsCollections.
  ///
  /// In en, this message translates to:
  /// **'Reopen on Books, Authors, Collections or Playlists, whichever you used last'**
  String get reopenOnBooksAuthorsCollections;

  /// No description provided for @collapseSeries.
  ///
  /// In en, this message translates to:
  /// **'Collapse series'**
  String get collapseSeries;

  /// No description provided for @showEachSeriesAsA.
  ///
  /// In en, this message translates to:
  /// **'Show each series as a single tile in the Books grid'**
  String get showEachSeriesAsA;

  /// No description provided for @maskServerAddress.
  ///
  /// In en, this message translates to:
  /// **'Mask server address'**
  String get maskServerAddress;

  /// No description provided for @hideTheAddressOnThe.
  ///
  /// In en, this message translates to:
  /// **'Hide the address on the Account and login screens until tapped'**
  String get hideTheAddressOnThe;

  /// No description provided for @hapticFeedback.
  ///
  /// In en, this message translates to:
  /// **'Haptic feedback'**
  String get hapticFeedback;

  /// No description provided for @keepScreenAwakeWhilePlaying.
  ///
  /// In en, this message translates to:
  /// **'Keep screen awake while playing'**
  String get keepScreenAwakeWhilePlaying;

  /// No description provided for @lockToPortrait.
  ///
  /// In en, this message translates to:
  /// **'Lock to portrait'**
  String get lockToPortrait;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @englishTheOnlyLanguageTranslated.
  ///
  /// In en, this message translates to:
  /// **'English is the only language for now. More languages will be added later.'**
  String get englishTheOnlyLanguageTranslated;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @itemsPerList.
  ///
  /// In en, this message translates to:
  /// **'Items per list'**
  String get itemsPerList;

  /// No description provided for @howManyEntriesEachBrowse.
  ///
  /// In en, this message translates to:
  /// **'How many entries each browse list shows'**
  String get howManyEntriesEachBrowse;

  /// No description provided for @newestBookFirstInA.
  ///
  /// In en, this message translates to:
  /// **'Newest book first in a series'**
  String get newestBookFirstInA;

  /// No description provided for @otherwiseBooksListInReading.
  ///
  /// In en, this message translates to:
  /// **'Otherwise books list in reading order'**
  String get otherwiseBooksListInReading;

  /// No description provided for @showSyncFailedIndicator.
  ///
  /// In en, this message translates to:
  /// **'Show sync-failed indicator'**
  String get showSyncFailedIndicator;

  /// No description provided for @badgeOnThePlayerWhile.
  ///
  /// In en, this message translates to:
  /// **'Badge on the player while progress updates are waiting to sync'**
  String get badgeOnThePlayerWhile;

  /// No description provided for @importOnDeviceAudioFiles.
  ///
  /// In en, this message translates to:
  /// **'Import on-device audio files that never came from the server'**
  String get importOnDeviceAudioFiles;

  /// No description provided for @unrestrictedBackgroundPlayback.
  ///
  /// In en, this message translates to:
  /// **'Unrestricted background playback'**
  String get unrestrictedBackgroundPlayback;

  /// No description provided for @progressSync.
  ///
  /// In en, this message translates to:
  /// **'Progress sync'**
  String get progressSync;

  /// No description provided for @retryNow.
  ///
  /// In en, this message translates to:
  /// **'Retry now'**
  String get retryNow;

  /// No description provided for @always.
  ///
  /// In en, this message translates to:
  /// **'Always'**
  String get always;

  /// No description provided for @ask.
  ///
  /// In en, this message translates to:
  /// **'Ask'**
  String get ask;

  /// No description provided for @never.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get never;

  /// No description provided for @historyWithCount.
  ///
  /// In en, this message translates to:
  /// **'History ({total})'**
  String historyWithCount(Object total);

  /// No description provided for @noListeningHistoryYet.
  ///
  /// In en, this message translates to:
  /// **'No listening history yet.'**
  String get noListeningHistoryYet;

  /// No description provided for @yearInReview.
  ///
  /// In en, this message translates to:
  /// **'Year in Review'**
  String get yearInReview;

  /// No description provided for @last7Days.
  ///
  /// In en, this message translates to:
  /// **'Last 7 Days'**
  String get last7Days;

  /// No description provided for @recentSessions.
  ///
  /// In en, this message translates to:
  /// **'Recent Sessions'**
  String get recentSessions;

  /// No description provided for @inReview.
  ///
  /// In en, this message translates to:
  /// **'{year} in Review'**
  String inReview(Object year);

  /// No description provided for @noListeningActivityYetThis.
  ///
  /// In en, this message translates to:
  /// **'No listening activity yet this year.'**
  String get noListeningActivityYetThis;

  /// No description provided for @listenedIn.
  ///
  /// In en, this message translates to:
  /// **'listened in {year}'**
  String listenedIn(Object year);

  /// No description provided for @topItems.
  ///
  /// In en, this message translates to:
  /// **'Top Items'**
  String get topItems;

  /// No description provided for @byDayOfWeek.
  ///
  /// In en, this message translates to:
  /// **'By day of week'**
  String get byDayOfWeek;

  /// No description provided for @markedFinished.
  ///
  /// In en, this message translates to:
  /// **'Marked finished'**
  String get markedFinished;

  /// No description provided for @markedNotFinished.
  ///
  /// In en, this message translates to:
  /// **'Marked not finished'**
  String get markedNotFinished;

  /// No description provided for @durationHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m'**
  String durationHoursMinutes(int hours, int minutes);

  /// No description provided for @durationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m'**
  String durationMinutes(int minutes);

  /// No description provided for @durationHoursDecimal.
  ///
  /// In en, this message translates to:
  /// **'{hours}h'**
  String durationHoursDecimal(String hours);

  /// No description provided for @finished.
  ///
  /// In en, this message translates to:
  /// **'Finished'**
  String get finished;

  /// No description provided for @percentComplete.
  ///
  /// In en, this message translates to:
  /// **'{percent}% complete'**
  String percentComplete(int percent);

  /// No description provided for @percentCompleteTimeLeft.
  ///
  /// In en, this message translates to:
  /// **'{percent}% complete · {time} left'**
  String percentCompleteTimeLeft(int percent, String time);

  /// No description provided for @chaptersCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 chapter} other{{count} chapters}}'**
  String chaptersCount(num count);

  /// No description provided for @allBooksAlreadyDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Every book in \"{series}\" is already downloaded.'**
  String allBooksAlreadyDownloaded(String series);

  /// No description provided for @downloadingBooksFromSeries.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Downloading 1 book from \"{series}\".} other{Downloading {count} books from \"{series}\".}}'**
  String downloadingBooksFromSeries(num count, String series);

  /// No description provided for @downloadingEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Downloading…'**
  String get downloadingEllipsis;

  /// No description provided for @episodes.
  ///
  /// In en, this message translates to:
  /// **'Episodes'**
  String get episodes;

  /// No description provided for @episodesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 episode} other{{count} episodes}}'**
  String episodesCount(num count);

  /// No description provided for @episodesCountIncomplete.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 episode} other{{count} episodes}} · {incomplete} incomplete'**
  String episodesCountIncomplete(num count, int incomplete);

  /// No description provided for @percentPlayed.
  ///
  /// In en, this message translates to:
  /// **'{percent}% played'**
  String percentPlayed(int percent);

  /// No description provided for @percentPlayedDuration.
  ///
  /// In en, this message translates to:
  /// **'{percent}% played · {duration}'**
  String percentPlayedDuration(int percent, String duration);

  /// No description provided for @downloadedWithSize.
  ///
  /// In en, this message translates to:
  /// **'Downloaded · {size}'**
  String downloadedWithSize(String size);

  /// No description provided for @calculatingStorage.
  ///
  /// In en, this message translates to:
  /// **'Calculating storage used…'**
  String get calculatingStorage;

  /// No description provided for @downloadsUse.
  ///
  /// In en, this message translates to:
  /// **'Downloads use {used}'**
  String downloadsUse(String used);

  /// No description provided for @downloadsUseWithFree.
  ///
  /// In en, this message translates to:
  /// **'Downloads use {used} · {free} free'**
  String downloadsUseWithFree(String used, String free);

  /// No description provided for @extractingPages.
  ///
  /// In en, this message translates to:
  /// **'Extracting pages…'**
  String get extractingPages;

  /// No description provided for @pageOfTotal.
  ///
  /// In en, this message translates to:
  /// **'{page} / {total}'**
  String pageOfTotal(Object page, Object total);

  /// No description provided for @chapterNumber.
  ///
  /// In en, this message translates to:
  /// **'Chapter {number}'**
  String chapterNumber(int number);

  /// No description provided for @sectionPlayback.
  ///
  /// In en, this message translates to:
  /// **'Playback'**
  String get sectionPlayback;

  /// No description provided for @sectionSleepTimer.
  ///
  /// In en, this message translates to:
  /// **'Sleep Timer'**
  String get sectionSleepTimer;

  /// No description provided for @sectionData.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get sectionData;

  /// No description provided for @sectionLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get sectionLibrary;

  /// No description provided for @sectionUserInterface.
  ///
  /// In en, this message translates to:
  /// **'User Interface'**
  String get sectionUserInterface;

  /// No description provided for @sectionEreader.
  ///
  /// In en, this message translates to:
  /// **'Ereader'**
  String get sectionEreader;

  /// No description provided for @sectionLinkedBooks.
  ///
  /// In en, this message translates to:
  /// **'Linked books'**
  String get sectionLinkedBooks;

  /// No description provided for @sectionStreaks.
  ///
  /// In en, this message translates to:
  /// **'Streaks'**
  String get sectionStreaks;

  /// No description provided for @showStreakChip.
  ///
  /// In en, this message translates to:
  /// **'Show streak on Home'**
  String get showStreakChip;

  /// No description provided for @showStreakChipHint.
  ///
  /// In en, this message translates to:
  /// **'A flame with your current streak in the Home bar'**
  String get showStreakChipHint;

  /// No description provided for @streakBar.
  ///
  /// In en, this message translates to:
  /// **'Daily bar'**
  String get streakBar;

  /// No description provided for @streakBarHint.
  ///
  /// In en, this message translates to:
  /// **'How much listening and reading counts as an active day'**
  String get streakBarHint;

  /// No description provided for @streakBarAny.
  ///
  /// In en, this message translates to:
  /// **'Any activity'**
  String get streakBarAny;

  /// No description provided for @streakBarMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String streakBarMinutes(int minutes);

  /// No description provided for @streakForgive.
  ///
  /// In en, this message translates to:
  /// **'Forgive a missed day'**
  String get streakForgive;

  /// No description provided for @streakForgiveHint.
  ///
  /// In en, this message translates to:
  /// **'One missed day is bridged, at most once a week'**
  String get streakForgiveHint;

  /// No description provided for @streakWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly streak'**
  String get streakWeekly;

  /// No description provided for @streakWeeklyHint.
  ///
  /// In en, this message translates to:
  /// **'Count weeks with at least one active day instead of days'**
  String get streakWeeklyHint;

  /// No description provided for @streakWeeks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 week} other{{count} weeks}}'**
  String streakWeeks(int count);

  /// No description provided for @streakAtRisk.
  ///
  /// In en, this message translates to:
  /// **'Listen or read today to keep it going'**
  String get streakAtRisk;

  /// No description provided for @streakSavedDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 missed day forgiven} other{{count} missed days forgiven}}'**
  String streakSavedDays(int count);

  /// No description provided for @longestStreak.
  ///
  /// In en, this message translates to:
  /// **'Longest streak'**
  String get longestStreak;

  /// No description provided for @streakBanner.
  ///
  /// In en, this message translates to:
  /// **'Keep your {unit} streak going: listen or read today'**
  String streakBanner(String unit);

  /// No description provided for @streakMilestone.
  ///
  /// In en, this message translates to:
  /// **'{unit} in a row. Nicely done!'**
  String streakMilestone(String unit);

  /// No description provided for @linkSyncMode.
  ///
  /// In en, this message translates to:
  /// **'Switch position'**
  String get linkSyncMode;

  /// No description provided for @linkSyncOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get linkSyncOff;

  /// No description provided for @linkSyncEstimated.
  ///
  /// In en, this message translates to:
  /// **'Estimated'**
  String get linkSyncEstimated;

  /// No description provided for @linkSyncOffHint.
  ///
  /// In en, this message translates to:
  /// **'Switching opens the other format where you left it'**
  String get linkSyncOffHint;

  /// No description provided for @linkSyncEstimatedHint.
  ///
  /// In en, this message translates to:
  /// **'Switching jumps to the matching chapter and spot'**
  String get linkSyncEstimatedHint;

  /// No description provided for @linkedEbook.
  ///
  /// In en, this message translates to:
  /// **'Linked ebook'**
  String get linkedEbook;

  /// No description provided for @linkedAudiobook.
  ///
  /// In en, this message translates to:
  /// **'Linked audiobook'**
  String get linkedAudiobook;

  /// No description provided for @linkBook.
  ///
  /// In en, this message translates to:
  /// **'Link ebook or audiobook'**
  String get linkBook;

  /// No description provided for @linkBookNone.
  ///
  /// In en, this message translates to:
  /// **'No matching book found'**
  String get linkBookNone;

  /// No description provided for @linkBookSearch.
  ///
  /// In en, this message translates to:
  /// **'Search by title'**
  String get linkBookSearch;

  /// No description provided for @linkBookPick.
  ///
  /// In en, this message translates to:
  /// **'Link to this book?'**
  String get linkBookPick;

  /// No description provided for @linkBookMatchedBy.
  ///
  /// In en, this message translates to:
  /// **'Matched by {reason}'**
  String linkBookMatchedBy(String reason);

  /// No description provided for @linkReasonAsin.
  ///
  /// In en, this message translates to:
  /// **'ASIN'**
  String get linkReasonAsin;

  /// No description provided for @linkReasonIsbn.
  ///
  /// In en, this message translates to:
  /// **'ISBN'**
  String get linkReasonIsbn;

  /// No description provided for @linkReasonAuthorTitle.
  ///
  /// In en, this message translates to:
  /// **'author and title'**
  String get linkReasonAuthorTitle;

  /// No description provided for @unlinkBook.
  ///
  /// In en, this message translates to:
  /// **'Unlink'**
  String get unlinkBook;

  /// No description provided for @listenLinked.
  ///
  /// In en, this message translates to:
  /// **'Listen'**
  String get listenLinked;

  /// No description provided for @readLinked.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get readLinked;

  /// No description provided for @sectionAndroidAuto.
  ///
  /// In en, this message translates to:
  /// **'Android Auto'**
  String get sectionAndroidAuto;

  /// No description provided for @sectionAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get sectionAdvanced;

  /// No description provided for @autoRewindOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get autoRewindOff;

  /// No description provided for @secondsShort.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s'**
  String secondsShort(int seconds);

  /// No description provided for @progressSyncAllSynced.
  ///
  /// In en, this message translates to:
  /// **'Everything is synced'**
  String get progressSyncAllSynced;

  /// No description provided for @updatesWaitingToSync.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 update waiting to sync} other{{count} updates waiting to sync}}'**
  String updatesWaitingToSync(num count);

  /// No description provided for @batteryExempt.
  ///
  /// In en, this message translates to:
  /// **'Exempt from battery optimization — audio won\'t be throttled while the phone is locked'**
  String get batteryExempt;

  /// No description provided for @batteryRecommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended — prevents Android from throttling audio focus and networking while the phone is locked'**
  String get batteryRecommended;

  /// No description provided for @sortTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get sortTitle;

  /// No description provided for @sortAuthor.
  ///
  /// In en, this message translates to:
  /// **'Author'**
  String get sortAuthor;

  /// No description provided for @sortDateAdded.
  ///
  /// In en, this message translates to:
  /// **'Date added'**
  String get sortDateAdded;

  /// No description provided for @sortPublishedYear.
  ///
  /// In en, this message translates to:
  /// **'Published year'**
  String get sortPublishedYear;

  /// No description provided for @sortDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get sortDuration;

  /// No description provided for @sortLastPlayed.
  ///
  /// In en, this message translates to:
  /// **'Last played'**
  String get sortLastPlayed;

  /// No description provided for @sortRandom.
  ///
  /// In en, this message translates to:
  /// **'Random'**
  String get sortRandom;

  /// No description provided for @filterGenre.
  ///
  /// In en, this message translates to:
  /// **'Genre'**
  String get filterGenre;

  /// No description provided for @filterTag.
  ///
  /// In en, this message translates to:
  /// **'Tag'**
  String get filterTag;

  /// No description provided for @filterAuthor.
  ///
  /// In en, this message translates to:
  /// **'Author'**
  String get filterAuthor;

  /// No description provided for @filterNarrator.
  ///
  /// In en, this message translates to:
  /// **'Narrator'**
  String get filterNarrator;

  /// No description provided for @filterSeries.
  ///
  /// In en, this message translates to:
  /// **'Series'**
  String get filterSeries;

  /// No description provided for @filterLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get filterLanguage;

  /// No description provided for @filterProgress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get filterProgress;

  /// No description provided for @filterEbook.
  ///
  /// In en, this message translates to:
  /// **'Ebook'**
  String get filterEbook;

  /// No description provided for @progressInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get progressInProgress;

  /// No description provided for @progressFinished.
  ///
  /// In en, this message translates to:
  /// **'Finished'**
  String get progressFinished;

  /// No description provided for @progressNotStarted.
  ///
  /// In en, this message translates to:
  /// **'Not started'**
  String get progressNotStarted;

  /// No description provided for @progressNotFinished.
  ///
  /// In en, this message translates to:
  /// **'Not finished'**
  String get progressNotFinished;

  /// No description provided for @ebookHas.
  ///
  /// In en, this message translates to:
  /// **'Has ebook'**
  String get ebookHas;

  /// No description provided for @ebookNone.
  ///
  /// In en, this message translates to:
  /// **'No ebook'**
  String get ebookNone;

  /// No description provided for @sectionBooks.
  ///
  /// In en, this message translates to:
  /// **'Books'**
  String get sectionBooks;

  /// No description provided for @sectionAuthors.
  ///
  /// In en, this message translates to:
  /// **'Authors'**
  String get sectionAuthors;

  /// No description provided for @sectionCollections.
  ///
  /// In en, this message translates to:
  /// **'Collections'**
  String get sectionCollections;

  /// No description provided for @sectionPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get sectionPlaylists;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeBlack.
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get themeBlack;

  /// No description provided for @themeSystemShort.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystemShort;

  /// No description provided for @skinGlassModernName.
  ///
  /// In en, this message translates to:
  /// **'Glass Modern'**
  String get skinGlassModernName;

  /// No description provided for @skinGlassModernDescription.
  ///
  /// In en, this message translates to:
  /// **'Frosted glass surfaces over a deep dark background, translucent cards.'**
  String get skinGlassModernDescription;

  /// No description provided for @skinBookshelfName.
  ///
  /// In en, this message translates to:
  /// **'Bookshelf'**
  String get skinBookshelfName;

  /// No description provided for @skinBookshelfDescription.
  ///
  /// In en, this message translates to:
  /// **'Warm wood and paper tones with book-spine styled covers.'**
  String get skinBookshelfDescription;

  /// No description provided for @sortAscending.
  ///
  /// In en, this message translates to:
  /// **'Ascending'**
  String get sortAscending;

  /// No description provided for @sortDescending.
  ///
  /// In en, this message translates to:
  /// **'Descending'**
  String get sortDescending;

  /// No description provided for @showEveryBook.
  ///
  /// In en, this message translates to:
  /// **'Show every book'**
  String get showEveryBook;

  /// No description provided for @collapseSeriesTooltip.
  ///
  /// In en, this message translates to:
  /// **'Collapse series'**
  String get collapseSeriesTooltip;

  /// No description provided for @listView.
  ///
  /// In en, this message translates to:
  /// **'List view'**
  String get listView;

  /// No description provided for @gridView.
  ///
  /// In en, this message translates to:
  /// **'Grid view'**
  String get gridView;

  /// No description provided for @skinSelectedSuffix.
  ///
  /// In en, this message translates to:
  /// **'{skin}, selected'**
  String skinSelectedSuffix(String skin);

  /// No description provided for @tabHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get tabHome;

  /// No description provided for @tabSeries.
  ///
  /// In en, this message translates to:
  /// **'Series'**
  String get tabSeries;

  /// No description provided for @tabLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get tabLibrary;

  /// No description provided for @live.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get live;

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get connecting;

  /// No description provided for @authFailed.
  ///
  /// In en, this message translates to:
  /// **'Auth failed'**
  String get authFailed;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// No description provided for @author.
  ///
  /// In en, this message translates to:
  /// **'Author'**
  String get author;

  /// No description provided for @collection.
  ///
  /// In en, this message translates to:
  /// **'Collection'**
  String get collection;

  /// No description provided for @playlist.
  ///
  /// In en, this message translates to:
  /// **'Playlist'**
  String get playlist;

  /// No description provided for @renameCollection.
  ///
  /// In en, this message translates to:
  /// **'Rename collection'**
  String get renameCollection;

  /// No description provided for @deleteCollectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete collection?'**
  String get deleteCollectionTitle;

  /// No description provided for @deleteCollectionMessage.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" will be deleted for everyone on this server.'**
  String deleteCollectionMessage(String name);

  /// No description provided for @renamePlaylist.
  ///
  /// In en, this message translates to:
  /// **'Rename playlist'**
  String get renamePlaylist;

  /// No description provided for @deletePlaylistTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete playlist?'**
  String get deletePlaylistTitle;

  /// No description provided for @deletePlaylistMessage.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" will be deleted.'**
  String deletePlaylistMessage(String name);

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @narrators.
  ///
  /// In en, this message translates to:
  /// **'Narrators'**
  String get narrators;

  /// No description provided for @genres.
  ///
  /// In en, this message translates to:
  /// **'Genres'**
  String get genres;

  /// No description provided for @tags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tags;

  /// No description provided for @nothingMatchesFilter.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches this filter.'**
  String get nothingMatchesFilter;

  /// No description provided for @libraryIsEmpty.
  ///
  /// In en, this message translates to:
  /// **'This library is empty.'**
  String get libraryIsEmpty;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @sleepTimerTooltipActive.
  ///
  /// In en, this message translates to:
  /// **'Sleep timer: {time}'**
  String sleepTimerTooltipActive(String time);

  /// No description provided for @sleepTimerTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sleep timer'**
  String get sleepTimerTooltip;

  /// No description provided for @chapterLabel.
  ///
  /// In en, this message translates to:
  /// **'Chapter'**
  String get chapterLabel;

  /// No description provided for @bookLabel.
  ///
  /// In en, this message translates to:
  /// **'Book'**
  String get bookLabel;

  /// No description provided for @trackNumber.
  ///
  /// In en, this message translates to:
  /// **'Track {number}'**
  String trackNumber(int number);

  /// No description provided for @speedInputError.
  ///
  /// In en, this message translates to:
  /// **'Enter a number between {min} and {max}.'**
  String speedInputError(Object min, Object max);

  /// No description provided for @hideExactSpeed.
  ///
  /// In en, this message translates to:
  /// **'Hide exact speed'**
  String get hideExactSpeed;

  /// No description provided for @enterExactSpeed.
  ///
  /// In en, this message translates to:
  /// **'Enter exact speed'**
  String get enterExactSpeed;

  /// No description provided for @startTimer.
  ///
  /// In en, this message translates to:
  /// **'Start timer'**
  String get startTimer;

  /// No description provided for @sleepTimerEnded.
  ///
  /// In en, this message translates to:
  /// **'Sleep timer ended'**
  String get sleepTimerEnded;

  /// No description provided for @chapterEndsIn.
  ///
  /// In en, this message translates to:
  /// **'Chapter ends in {time}'**
  String chapterEndsIn(String time);

  /// No description provided for @sleepIn.
  ///
  /// In en, this message translates to:
  /// **'Sleep in {time}'**
  String sleepIn(String time);

  /// No description provided for @dailyAverage.
  ///
  /// In en, this message translates to:
  /// **'Daily average'**
  String get dailyAverage;

  /// No description provided for @bestDay.
  ///
  /// In en, this message translates to:
  /// **'Best day'**
  String get bestDay;

  /// No description provided for @daysListened.
  ///
  /// In en, this message translates to:
  /// **'Days listened'**
  String get daysListened;

  /// No description provided for @currentStreak.
  ///
  /// In en, this message translates to:
  /// **'Current streak'**
  String get currentStreak;

  /// No description provided for @thisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get thisWeek;

  /// No description provided for @itemsFinished.
  ///
  /// In en, this message translates to:
  /// **'Items finished'**
  String get itemsFinished;

  /// No description provided for @streakDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String streakDays(num count);

  /// No description provided for @daysActive.
  ///
  /// In en, this message translates to:
  /// **'Days active'**
  String get daysActive;

  /// No description provided for @streakDaysShort.
  ///
  /// In en, this message translates to:
  /// **'{count}d'**
  String streakDaysShort(int count);

  /// No description provided for @logEntrySubtitle.
  ///
  /// In en, this message translates to:
  /// **'{tag} · {when}'**
  String logEntrySubtitle(String tag, String when);

  /// No description provided for @logEntrySubtitleRepeated.
  ///
  /// In en, this message translates to:
  /// **'{tag} · {when} · ×{count}'**
  String logEntrySubtitleRepeated(String tag, String when, int count);

  /// No description provided for @enterServerAddress.
  ///
  /// In en, this message translates to:
  /// **'Enter a server address.'**
  String get enterServerAddress;

  /// No description provided for @notAudiobookshelf.
  ///
  /// In en, this message translates to:
  /// **'That doesn\'t look like an Audiobookshelf server.'**
  String get notAudiobookshelf;

  /// No description provided for @serverNotInitialized.
  ///
  /// In en, this message translates to:
  /// **'This server has no admin account set up yet — finish setup in a browser first.'**
  String get serverNotInitialized;

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get somethingWentWrong;

  /// No description provided for @couldntReachCheckConnection.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach that server — check the address and your connection.'**
  String get couldntReachCheckConnection;

  /// No description provided for @couldntConnectCheckServer.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t connect. Check the address and that the server is online.'**
  String get couldntConnectCheckServer;

  /// No description provided for @serverRespondedWithError.
  ///
  /// In en, this message translates to:
  /// **'Server responded with an error ({code}). Check the address.'**
  String serverRespondedWithError(Object code);

  /// No description provided for @couldntReachTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach that server. Check the address and try again.'**
  String get couldntReachTryAgain;

  /// No description provided for @enterUsername.
  ///
  /// In en, this message translates to:
  /// **'Enter a username.'**
  String get enterUsername;

  /// No description provided for @incorrectCredentials.
  ///
  /// In en, this message translates to:
  /// **'Incorrect username or password.'**
  String get incorrectCredentials;

  /// No description provided for @lostConnection.
  ///
  /// In en, this message translates to:
  /// **'Lost connection to the server.'**
  String get lostConnection;

  /// No description provided for @loginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed. Try again.'**
  String get loginFailed;

  /// No description provided for @couldntChangePasswordCheckCurrent.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t change your password. Check your current password.'**
  String get couldntChangePasswordCheckCurrent;

  /// No description provided for @passwordChangeNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'Your account isn\'t allowed to change its password.'**
  String get passwordChangeNotAllowed;

  /// No description provided for @tooManyAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait a minute and try again.'**
  String get tooManyAttempts;

  /// No description provided for @couldntChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t change your password. Try again.'**
  String get couldntChangePassword;

  /// No description provided for @pwEnterCurrent.
  ///
  /// In en, this message translates to:
  /// **'Enter your current password.'**
  String get pwEnterCurrent;

  /// No description provided for @pwEnterNew.
  ///
  /// In en, this message translates to:
  /// **'Enter a new password.'**
  String get pwEnterNew;

  /// No description provided for @pwTooShort.
  ///
  /// In en, this message translates to:
  /// **'New password must be at least {min} characters.'**
  String pwTooShort(int min);

  /// No description provided for @pwSame.
  ///
  /// In en, this message translates to:
  /// **'New password must be different from your current one.'**
  String get pwSame;

  /// No description provided for @pwMismatch.
  ///
  /// In en, this message translates to:
  /// **'New passwords don\'t match.'**
  String get pwMismatch;

  /// No description provided for @cellularStreamTitle.
  ///
  /// In en, this message translates to:
  /// **'Stream over cellular?'**
  String get cellularStreamTitle;

  /// No description provided for @cellularDownloadTitle.
  ///
  /// In en, this message translates to:
  /// **'Download over cellular?'**
  String get cellularDownloadTitle;

  /// No description provided for @cellularStreamBody.
  ///
  /// In en, this message translates to:
  /// **'You\'re on a mobile connection. Streaming will use your data. Your choice is remembered until the app restarts.'**
  String get cellularStreamBody;

  /// No description provided for @cellularDownloadBody.
  ///
  /// In en, this message translates to:
  /// **'You\'re on a mobile connection. Downloading will use your data. Your choice is remembered until the app restarts.'**
  String get cellularDownloadBody;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// No description provided for @streamAction.
  ///
  /// In en, this message translates to:
  /// **'Stream'**
  String get streamAction;

  /// No description provided for @downloadAction.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get downloadAction;

  /// No description provided for @cellularStreamBlocked.
  ///
  /// In en, this message translates to:
  /// **'Streaming over cellular is off in Settings → Data.'**
  String get cellularStreamBlocked;

  /// No description provided for @cellularDownloadBlocked.
  ///
  /// In en, this message translates to:
  /// **'Downloading over cellular is off in Settings → Data.'**
  String get cellularDownloadBlocked;

  /// No description provided for @switchAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Switch account?'**
  String get switchAccountTitle;

  /// No description provided for @switchAccountWhilePlaying.
  ///
  /// In en, this message translates to:
  /// **'Playback will stop. Switch to {server}?'**
  String switchAccountWhilePlaying(String server);

  /// No description provided for @switchAction.
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get switchAction;

  /// No description provided for @removeAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String removeAccountTitle(String name);

  /// No description provided for @removeAccountMessage.
  ///
  /// In en, this message translates to:
  /// **'Signs out of {server} on this device. Downloads from it can be kept or deleted.'**
  String removeAccountMessage(String server);

  /// No description provided for @removeAndDeleteDownloads.
  ///
  /// In en, this message translates to:
  /// **'Remove and delete downloads'**
  String get removeAndDeleteDownloads;

  /// No description provided for @removeKeepDownloads.
  ///
  /// In en, this message translates to:
  /// **'Remove, keep downloads'**
  String get removeKeepDownloads;

  /// No description provided for @accounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get accounts;

  /// No description provided for @menu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menu;

  /// No description provided for @addServerOrAccount.
  ///
  /// In en, this message translates to:
  /// **'Add server or account'**
  String get addServerOrAccount;

  /// No description provided for @manageAccounts.
  ///
  /// In en, this message translates to:
  /// **'Manage accounts'**
  String get manageAccounts;

  /// No description provided for @continueAsAccount.
  ///
  /// In en, this message translates to:
  /// **'Continue as {name}'**
  String continueAsAccount(String name);

  /// No description provided for @savedAccounts.
  ///
  /// In en, this message translates to:
  /// **'Saved accounts'**
  String get savedAccounts;

  /// No description provided for @sectionAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get sectionAccount;

  /// No description provided for @askBeforeSwitching.
  ///
  /// In en, this message translates to:
  /// **'Ask before switching while playing'**
  String get askBeforeSwitching;

  /// No description provided for @askBeforeSwitchingHint.
  ///
  /// In en, this message translates to:
  /// **'Switching servers or accounts stops playback'**
  String get askBeforeSwitchingHint;

  /// No description provided for @showOtherServerDownloads.
  ///
  /// In en, this message translates to:
  /// **'Show downloads from other servers'**
  String get showOtherServerDownloads;

  /// No description provided for @showOtherServerDownloadsHint.
  ///
  /// In en, this message translates to:
  /// **'Keep downloaded books from your other servers in the Downloads list'**
  String get showOtherServerDownloadsHint;

  /// No description provided for @downloadsFromServer.
  ///
  /// In en, this message translates to:
  /// **'Downloads from {server}'**
  String downloadsFromServer(String server);

  /// No description provided for @accountOnServer.
  ///
  /// In en, this message translates to:
  /// **'{name} on {server}'**
  String accountOnServer(String name, String server);

  /// No description provided for @addAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Add server or account'**
  String get addAccountTitle;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @readingProgress.
  ///
  /// In en, this message translates to:
  /// **'Reading progress'**
  String get readingProgress;

  /// No description provided for @highlight.
  ///
  /// In en, this message translates to:
  /// **'Highlight'**
  String get highlight;

  /// No description provided for @bookmarkThisPage.
  ///
  /// In en, this message translates to:
  /// **'Bookmark this page'**
  String get bookmarkThisPage;

  /// No description provided for @bookmarksAndHighlights.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks and highlights'**
  String get bookmarksAndHighlights;

  /// No description provided for @highlights.
  ///
  /// In en, this message translates to:
  /// **'Highlights'**
  String get highlights;

  /// No description provided for @noHighlightsYet.
  ///
  /// In en, this message translates to:
  /// **'No highlights yet. Select text and choose Highlight.'**
  String get noHighlightsYet;

  /// No description provided for @epubReadingMode.
  ///
  /// In en, this message translates to:
  /// **'Books (EPUB)'**
  String get epubReadingMode;

  /// No description provided for @pdfReadingMode.
  ///
  /// In en, this message translates to:
  /// **'PDF'**
  String get pdfReadingMode;

  /// No description provided for @comicReadingMode.
  ///
  /// In en, this message translates to:
  /// **'Comics'**
  String get comicReadingMode;

  /// No description provided for @pagedMode.
  ///
  /// In en, this message translates to:
  /// **'Pages'**
  String get pagedMode;

  /// No description provided for @scrollMode.
  ///
  /// In en, this message translates to:
  /// **'Scroll'**
  String get scrollMode;

  /// No description provided for @tapToTurnPages.
  ///
  /// In en, this message translates to:
  /// **'Tap screen edges to turn pages'**
  String get tapToTurnPages;

  /// No description provided for @keepScreenOn.
  ///
  /// In en, this message translates to:
  /// **'Keep screen on while reading'**
  String get keepScreenOn;

  /// No description provided for @brightness.
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get brightness;

  /// No description provided for @justifyText.
  ///
  /// In en, this message translates to:
  /// **'Justify text'**
  String get justifyText;

  /// No description provided for @margins.
  ///
  /// In en, this message translates to:
  /// **'Margins'**
  String get margins;

  /// No description provided for @readingPercent.
  ///
  /// In en, this message translates to:
  /// **'Continue reading ({percent}%)'**
  String readingPercent(int percent);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
