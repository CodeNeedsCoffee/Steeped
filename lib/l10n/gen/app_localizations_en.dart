// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Steeped';

  @override
  String get connectToServer => 'Connect to Server';

  @override
  String get enterYourAudiobookshelfServerAddress =>
      'Enter your Audiobookshelf server address';

  @override
  String get serverAddress => 'Server address';

  @override
  String get audiobookshelfExampleCom => 'audiobookshelf.example.com';

  @override
  String get continueLabel => 'Continue';

  @override
  String get logIn => 'Log In';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get deleteAllDownloadsTitle => 'Delete all downloads?';

  @override
  String get thisRemovesEveryDownloadedBook =>
      'This removes every downloaded book and episode from this device. They remain on the server and can be downloaded again.';

  @override
  String get cancel => 'Cancel';

  @override
  String get deleteAll => 'Delete All';

  @override
  String get downloads => 'Downloads';

  @override
  String get deleteAllDownloadsTooltip => 'Delete all downloads';

  @override
  String failedToLoad(Object error) {
    return 'Failed to load: $error';
  }

  @override
  String get noDownloadsYet => 'No downloads yet.';

  @override
  String get deleteDownload => 'Delete download';

  @override
  String get storageIsRunningLowDelete =>
      'Storage is running low. Delete a download to free up space.';

  @override
  String get tableOfContents => 'Table of Contents';

  @override
  String get readingSettingsTooltip => 'Reading settings';

  @override
  String get downloadingBook => 'Downloading book…';

  @override
  String get readingSettings => 'Reading Settings';

  @override
  String get font => 'Font';

  @override
  String get sans => 'Sans';

  @override
  String get serif => 'Serif';

  @override
  String get bold => 'Bold';

  @override
  String get fontSize => 'Font size';

  @override
  String get lineSpacing => 'Line spacing';

  @override
  String get theme => 'Theme';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get black => 'Black';

  @override
  String get downloading => 'Downloading…';

  @override
  String get noLibrariesOnThisServer => 'No libraries on this server.';

  @override
  String failedToLoadLibraries(Object error) {
    return 'Failed to load libraries: $error';
  }

  @override
  String get retry => 'Retry';

  @override
  String get viewDownloads => 'View Downloads';

  @override
  String get search => 'Search';

  @override
  String get settings => 'Settings';

  @override
  String get latestEpisodes => 'Latest Episodes';

  @override
  String failedToLoadHomeShelves(Object error) {
    return 'Failed to load home shelves: $error';
  }

  @override
  String get nothingToShowYet => 'Nothing to show yet.';

  @override
  String failedToLoadSeries(Object error) {
    return 'Failed to load series: $error';
  }

  @override
  String get noSeriesInThisLibrary => 'No series in this library.';

  @override
  String bookCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count books',
      one: '1 book',
    );
    return '$_temp0';
  }

  @override
  String get canTReachTheServer =>
      'Can\'t reach the server. Showing downloaded content.';

  @override
  String get continueListening => 'Continue Listening';

  @override
  String get noDownloadedContentYet => 'No downloaded content yet.';

  @override
  String browsingNeedsAConnection(Object label) {
    return '$label browsing needs a connection.';
  }

  @override
  String get moreActions => 'More actions';

  @override
  String get discardProgressButton => 'Discard progress';

  @override
  String get play => 'Play';

  @override
  String get read => 'Read';

  @override
  String get readAgain => 'Read again';

  @override
  String narratedBy(Object join) {
    return 'Narrated by $join';
  }

  @override
  String isnTSupportedYetNo(Object format) {
    return '.$format isn\'t supported yet — no pure-Dart RAR decoder exists for CBR.';
  }

  @override
  String downloadSeries(Object name) {
    return 'Download series: $name';
  }

  @override
  String get download => 'Download';

  @override
  String get downloaded => 'Downloaded';

  @override
  String get name => 'Name';

  @override
  String couldNotLoadPlaylists(Object e) {
    return 'Could not load playlists: $e';
  }

  @override
  String get addToPlaylist => 'Add to playlist';

  @override
  String get newPlaylistEllipsis => 'New playlist…';

  @override
  String addedTo(Object name) {
    return 'Added to \"$name\"';
  }

  @override
  String couldNotCreatePlaylist(Object e) {
    return 'Could not create playlist: $e';
  }

  @override
  String itemCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String playlistUpdateFailed(Object e) {
    return 'Playlist update failed: $e';
  }

  @override
  String couldNotLoadCollections(Object e) {
    return 'Could not load collections: $e';
  }

  @override
  String get addToCollection => 'Add to collection';

  @override
  String get newCollectionEllipsis => 'New collection…';

  @override
  String couldNotCreateCollection(Object e) {
    return 'Could not create collection: $e';
  }

  @override
  String books(Object count) {
    return '$count books';
  }

  @override
  String collectionUpdateFailed(Object e) {
    return 'Collection update failed: $e';
  }

  @override
  String get goToAuthor => 'Go to author';

  @override
  String get goToSeries => 'Go to series';

  @override
  String get details => 'Details';

  @override
  String get downloadStarted => 'Download started';

  @override
  String downloadFailed(Object e) {
    return 'Download failed: $e';
  }

  @override
  String get markFinished => 'Mark finished';

  @override
  String get markNotFinished => 'Mark not finished';

  @override
  String couldNotUpdate(Object e) {
    return 'Could not update: $e';
  }

  @override
  String get notAvailableForThisItem => 'Not available for this item';

  @override
  String couldNotOpen(Object e) {
    return 'Could not open: $e';
  }

  @override
  String failedToLoadAuthors(Object e) {
    return 'Failed to load authors: $e';
  }

  @override
  String get noAuthorsInThisLibrary => 'No authors in this library.';

  @override
  String failedToLoadCollections(Object e) {
    return 'Failed to load collections: $e';
  }

  @override
  String get newCollection => 'New collection';

  @override
  String get noCollectionsYet => 'No collections yet.';

  @override
  String bookCountDuration(num count, String duration) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count books',
      one: '1 book',
    );
    return '$_temp0 · $duration';
  }

  @override
  String failedToLoadPlaylists(Object e) {
    return 'Failed to load playlists: $e';
  }

  @override
  String get newPlaylist => 'New playlist';

  @override
  String get noPlaylistsYet => 'No playlists yet.';

  @override
  String itemCountDuration(num count, String duration) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0 · $duration';
  }

  @override
  String failedToLoadAuthor(Object e) {
    return 'Failed to load author: $e';
  }

  @override
  String get rename => 'Rename';

  @override
  String get delete => 'Delete';

  @override
  String failedToLoadCollection(Object e) {
    return 'Failed to load collection: $e';
  }

  @override
  String get playAll => 'Play all';

  @override
  String get downloadAll => 'Download all';

  @override
  String queuedDownloads(Object n) {
    return 'Queued $n downloads';
  }

  @override
  String get thisCollectionIsEmpty => 'This collection is empty.';

  @override
  String get removeFromCollection => 'Remove from collection';

  @override
  String couldNotReorder(Object e) {
    return 'Could not reorder: $e';
  }

  @override
  String failedToLoadPlaylist(Object e) {
    return 'Failed to load playlist: $e';
  }

  @override
  String get thisPlaylistIsEmpty => 'This playlist is empty.';

  @override
  String get remove => 'Remove';

  @override
  String libraryLabel(Object total) {
    return 'Library ($total)';
  }

  @override
  String get sort => 'Sort';

  @override
  String get filter => 'Filter';

  @override
  String get clearAll => 'Clear all';

  @override
  String couldNotLoadFilters(Object e) {
    return 'Could not load filters: $e';
  }

  @override
  String get filterBy => 'Filter by';

  @override
  String get back => 'Back';

  @override
  String get nothingToFilterOn => 'Nothing to filter on.';

  @override
  String get searchBooksSeriesAuthors => 'Search books, series, authors…';

  @override
  String get noResults => 'No results.';

  @override
  String get searchInBook => 'Search in book';

  @override
  String get searchInBookHint => 'Type at least 2 letters';

  @override
  String timeLeftInBook(String duration) {
    return '$duration left';
  }

  @override
  String searchFailed(Object error) {
    return 'Search failed: $error';
  }

  @override
  String get searchThisLibrary => 'Search this library.';

  @override
  String get recentSearches => 'Recent searches';

  @override
  String get clear => 'Clear';

  @override
  String get seriesUnavailable => 'Series unavailable.';

  @override
  String get localMedia => 'Local Media';

  @override
  String get importAFile => 'Import a file';

  @override
  String imported(Object title) {
    return 'Imported \"$title\"';
  }

  @override
  String get noLocalMediaYetTap =>
      'No local media yet. Tap + to import an audio file from this device — these never touch the server.';

  @override
  String get discardProgressTitle => 'Discard progress?';

  @override
  String allListeningProgressForWill(Object title) {
    return 'All listening progress for \"$title\" will be removed. The book itself is not affected.';
  }

  @override
  String get discard => 'Discard';

  @override
  String get progressDiscarded => 'Progress discarded';

  @override
  String couldNotDiscardProgress(Object e) {
    return 'Could not discard progress: $e';
  }

  @override
  String get expand => 'Expand';

  @override
  String rewindSeconds(Object jumpBackSeconds) {
    return 'Rewind $jumpBackSeconds seconds';
  }

  @override
  String forwardSeconds(Object jumpForwardSeconds) {
    return 'Forward $jumpForwardSeconds seconds';
  }

  @override
  String get close => 'Close';

  @override
  String get stopPlayback => 'Stop and close player';

  @override
  String get queue => 'Queue';

  @override
  String get timeDisplayTooltip => 'Time display';

  @override
  String get sleepTimer => 'Sleep Timer';

  @override
  String get timeDisplayMenu => 'Time Display';

  @override
  String get markAsFinished => 'Mark as Finished';

  @override
  String get markAsNotFinished => 'Mark as Not Finished';

  @override
  String get discardProgressMenu => 'Discard Progress';

  @override
  String get bookmarks => 'Bookmarks';

  @override
  String get chapters => 'Chapters';

  @override
  String get tracks => 'Tracks';

  @override
  String minutes(Object minutes) {
    return '$minutes minutes';
  }

  @override
  String get endOfChapter => 'End of chapter';

  @override
  String get cancelTimer => 'Cancel timer';

  @override
  String get queueFinished => 'Queue finished.';

  @override
  String queueNamed(Object name) {
    return 'Queue: $name';
  }

  @override
  String get removeFromQueue => 'Remove from queue';

  @override
  String get noBookmarksYet => 'No bookmarks yet';

  @override
  String get deleteBookmarkTooltip => 'Delete bookmark';

  @override
  String get addBookmarkAtCurrentPosition => 'Add bookmark at current position';

  @override
  String get addBookmark => 'Add Bookmark';

  @override
  String get note => 'Note';

  @override
  String get add => 'Add';

  @override
  String get failedToAddBookmark => 'Failed to add bookmark';

  @override
  String get deleteBookmarkTitle => 'Delete bookmark?';

  @override
  String thisRemovesFromTheServer(Object title) {
    return 'This removes \"$title\" from the server.';
  }

  @override
  String get failedToDeleteBookmark => 'Failed to delete bookmark';

  @override
  String get playbackSpeed => 'Playback Speed';

  @override
  String get exactSpeed => 'Exact speed';

  @override
  String get setLabel => 'Set';

  @override
  String get resetTo1x => 'Reset to 1x';

  @override
  String get restart => 'Restart';

  @override
  String min(Object sleepExtendMinutes) {
    return '+$sleepExtendMinutes min';
  }

  @override
  String get dismiss => 'Dismiss';

  @override
  String syncWaitingTooltip(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count progress updates',
      one: '1 progress update',
    );
    return '$_temp0 waiting to sync — tap to retry';
  }

  @override
  String get chapter => 'Chapter';

  @override
  String get book => 'Book';

  @override
  String get noEpisodesYet => 'No episodes yet.';

  @override
  String get downloadEpisode => 'Download episode';

  @override
  String get deleteDownloadedEpisode => 'Delete downloaded episode';

  @override
  String get noRecentEpisodes => 'No recent episodes.';

  @override
  String get account => 'Account';

  @override
  String get server => 'Server';

  @override
  String get downloadsAllowed => 'Downloads allowed';

  @override
  String get uploadsAllowed => 'Uploads allowed';

  @override
  String get updatesAllowed => 'Updates allowed';

  @override
  String get deletesAllowed => 'Deletes allowed';

  @override
  String get changePassword => 'Change Password';

  @override
  String get logOut => 'Log Out';

  @override
  String get appearance => 'Appearance';

  @override
  String get skin => 'Skin';

  @override
  String get passwordChanged => 'Password changed.';

  @override
  String get currentPassword => 'Current password';

  @override
  String get newPassword => 'New password';

  @override
  String atLeastCharacters(Object minPasswordLength) {
    return 'At least $minPasswordLength characters';
  }

  @override
  String get confirmNewPassword => 'Confirm new password';

  @override
  String get changingYourPasswordSignsYou =>
      'Changing your password signs you out on your other devices. This one stays signed in.';

  @override
  String get logs => 'Logs';

  @override
  String get clearLogs => 'Clear logs';

  @override
  String get noLogEntriesYet => 'No log entries yet.';

  @override
  String get stats => 'Stats';

  @override
  String get history => 'History';

  @override
  String get rssFeeds => 'RSS Feeds';

  @override
  String get adminNotYetImplemented => 'Admin tools will be added later';

  @override
  String get jumpBack => 'Jump back';

  @override
  String get jumpForward => 'Jump forward';

  @override
  String get allowSeekingOnLockScreen =>
      'Allow seeking on lock-screen controls';

  @override
  String get showADraggableProgressBar =>
      'Show a draggable progress bar in the notification and lock screen';

  @override
  String get autoRewindOnResume => 'Auto-rewind on resume';

  @override
  String get stepBackALittleWhen => 'Step back a little when you press play';

  @override
  String get rewindFurtherAfterLongPauses => 'Rewind further after long pauses';

  @override
  String get autoRewindScaleHint => '2x after 5 minutes, 3x after an hour';

  @override
  String get scaleElapsedTimeBySpeed => 'Scale elapsed time by speed';

  @override
  String get showNowPlayingSTime =>
      'Show Now Playing\'s time as real-world minutes at your current speed';

  @override
  String get showTracksTab => 'Show Tracks tab';

  @override
  String get onNowPlayingAddA =>
      'On Now Playing, add a toggle to switch between chapters and a multi-file book\'s raw audio-file tracks';

  @override
  String get defaultDuration => 'Default duration';

  @override
  String get extendBy => 'Extend by';

  @override
  String get fadeOutBeforePausing => 'Fade out before pausing';

  @override
  String get fadeLength => 'Fade length';

  @override
  String get sleepChimeBeforePausing => 'Chime 30 seconds before pausing';

  @override
  String get startAutomaticallyAtNight => 'Start automatically at night';

  @override
  String get beginTheDefaultTimerWhen =>
      'Begin the default timer when playback starts inside the window';

  @override
  String get treatMeteredWiFiLike => 'Treat metered Wi-Fi like cellular';

  @override
  String get applyTheChoicesAboveTo =>
      'Apply the choices above to metered Wi-Fi, such as a phone hotspot';

  @override
  String get rememberLibrarySection => 'Remember library section';

  @override
  String get reopenOnBooksAuthorsCollections =>
      'Reopen on Books, Authors, Collections or Playlists, whichever you used last';

  @override
  String get collapseSeries => 'Collapse series';

  @override
  String get showEachSeriesAsA =>
      'Show each series as a single tile in the Books grid';

  @override
  String get maskServerAddress => 'Mask server address';

  @override
  String get hideTheAddressOnThe =>
      'Hide the address on the Account and login screens until tapped';

  @override
  String get hapticFeedback => 'Haptic feedback';

  @override
  String get keepScreenAwakeWhilePlaying => 'Keep screen awake while playing';

  @override
  String get lockToPortrait => 'Lock to portrait';

  @override
  String get language => 'Language';

  @override
  String get englishTheOnlyLanguageTranslated =>
      'English is the only language for now. More languages will be added later.';

  @override
  String get english => 'English';

  @override
  String get itemsPerList => 'Items per list';

  @override
  String get howManyEntriesEachBrowse =>
      'How many entries each browse list shows';

  @override
  String get newestBookFirstInA => 'Newest book first in a series';

  @override
  String get otherwiseBooksListInReading =>
      'Otherwise books list in reading order';

  @override
  String get showSyncFailedIndicator => 'Show sync-failed indicator';

  @override
  String get badgeOnThePlayerWhile =>
      'Badge on the player while progress updates are waiting to sync';

  @override
  String get importOnDeviceAudioFiles =>
      'Import on-device audio files that never came from the server';

  @override
  String get unrestrictedBackgroundPlayback =>
      'Unrestricted background playback';

  @override
  String get progressSync => 'Progress sync';

  @override
  String get retryNow => 'Retry now';

  @override
  String get always => 'Always';

  @override
  String get ask => 'Ask';

  @override
  String get never => 'Never';

  @override
  String historyWithCount(Object total) {
    return 'History ($total)';
  }

  @override
  String get noListeningHistoryYet => 'No listening history yet.';

  @override
  String get yearInReview => 'Year in Review';

  @override
  String get last7Days => 'Last 7 Days';

  @override
  String get recentSessions => 'Recent Sessions';

  @override
  String inReview(Object year) {
    return '$year in Review';
  }

  @override
  String get noListeningActivityYetThis =>
      'No listening activity yet this year.';

  @override
  String listenedIn(Object year) {
    return 'listened in $year';
  }

  @override
  String get topItems => 'Top Items';

  @override
  String get byDayOfWeek => 'By day of week';

  @override
  String get markedFinished => 'Marked finished';

  @override
  String get markedNotFinished => 'Marked not finished';

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String durationMinutes(int minutes) {
    return '${minutes}m';
  }

  @override
  String durationHoursDecimal(String hours) {
    return '${hours}h';
  }

  @override
  String get finished => 'Finished';

  @override
  String percentComplete(int percent) {
    return '$percent% complete';
  }

  @override
  String percentCompleteTimeLeft(int percent, String time) {
    return '$percent% complete · $time left';
  }

  @override
  String chaptersCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chapters',
      one: '1 chapter',
    );
    return '$_temp0';
  }

  @override
  String allBooksAlreadyDownloaded(String series) {
    return 'Every book in \"$series\" is already downloaded.';
  }

  @override
  String downloadingBooksFromSeries(num count, String series) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Downloading $count books from \"$series\".',
      one: 'Downloading 1 book from \"$series\".',
    );
    return '$_temp0';
  }

  @override
  String get downloadingEllipsis => 'Downloading…';

  @override
  String get episodes => 'Episodes';

  @override
  String episodesCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count episodes',
      one: '1 episode',
    );
    return '$_temp0';
  }

  @override
  String episodesCountIncomplete(num count, int incomplete) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count episodes',
      one: '1 episode',
    );
    return '$_temp0 · $incomplete incomplete';
  }

  @override
  String percentPlayed(int percent) {
    return '$percent% played';
  }

  @override
  String percentPlayedDuration(int percent, String duration) {
    return '$percent% played · $duration';
  }

  @override
  String downloadedWithSize(String size) {
    return 'Downloaded · $size';
  }

  @override
  String get calculatingStorage => 'Calculating storage used…';

  @override
  String downloadsUse(String used) {
    return 'Downloads use $used';
  }

  @override
  String downloadsUseWithFree(String used, String free) {
    return 'Downloads use $used · $free free';
  }

  @override
  String get extractingPages => 'Extracting pages…';

  @override
  String pageOfTotal(Object page, Object total) {
    return '$page / $total';
  }

  @override
  String chapterNumber(int number) {
    return 'Chapter $number';
  }

  @override
  String get sectionPlayback => 'Playback';

  @override
  String get sectionSleepTimer => 'Sleep Timer';

  @override
  String get sectionData => 'Data';

  @override
  String get sectionLibrary => 'Library';

  @override
  String get sectionUserInterface => 'User Interface';

  @override
  String get sectionEreader => 'Ereader';

  @override
  String get sectionLinkedBooks => 'Linked books';

  @override
  String get sectionStreaks => 'Streaks';

  @override
  String get showStreakChip => 'Show streak on Home';

  @override
  String get showStreakChipHint =>
      'A flame with your current streak in the Home bar';

  @override
  String get streakBar => 'Daily bar';

  @override
  String get streakBarHint =>
      'How much listening and reading counts as an active day';

  @override
  String get streakBarAny => 'Any activity';

  @override
  String streakBarMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get streakForgive => 'Forgive a missed day';

  @override
  String get streakForgiveHint =>
      'One missed day is bridged, at most once a week';

  @override
  String get streakWeekly => 'Weekly streak';

  @override
  String get streakWeeklyHint =>
      'Count weeks with at least one active day instead of days';

  @override
  String streakWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weeks',
      one: '1 week',
    );
    return '$_temp0';
  }

  @override
  String get streakAtRisk => 'Listen or read today to keep it going';

  @override
  String streakSavedDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count missed days forgiven',
      one: '1 missed day forgiven',
    );
    return '$_temp0';
  }

  @override
  String get longestStreak => 'Longest streak';

  @override
  String get streakReminder => 'Daily reminder';

  @override
  String get streakReminderHint =>
      'A notification in the evening if you have a streak and have not listened or read yet';

  @override
  String get streakReminderTime => 'Reminder time';

  @override
  String get streakReminderTest => 'Send a test reminder';

  @override
  String get streakReminderTestHint => 'Shows one in a few seconds';

  @override
  String get streakReminderQuiet => 'Quiet hours';

  @override
  String get streakReminderQuietHint => 'No reminders between 10 pm and 8 am';

  @override
  String get streakReminderAskTitle => 'Turn on reminders?';

  @override
  String get streakReminderAskBody =>
      'Steeped will send one notification a day, only when you have a streak going and have not listened or read yet. It is created on this phone; nothing is sent to a server. You can turn it off here at any time.';

  @override
  String get streakReminderAskTurnOn => 'Turn on';

  @override
  String get streakReminderDenied =>
      'Notifications are turned off for Steeped. Allow them in the system settings to get reminders.';

  @override
  String get reminderChannelName => 'Streak reminders';

  @override
  String get reminderTitle => 'Steeped';

  @override
  String streakBanner(String unit) {
    return 'Keep your $unit streak going: listen or read today';
  }

  @override
  String streakMilestone(String unit) {
    return '$unit in a row. Nicely done!';
  }

  @override
  String get linkSyncMode => 'Switch position';

  @override
  String get linkSyncOff => 'Off';

  @override
  String get linkSyncEstimated => 'Estimated';

  @override
  String get linkSyncOffHint =>
      'Switching opens the other format where you left it';

  @override
  String get linkSyncEstimatedHint =>
      'Switching jumps to the matching chapter and spot';

  @override
  String get linkedEbook => 'Linked ebook';

  @override
  String get linkedAudiobook => 'Linked audiobook';

  @override
  String get linkBook => 'Link ebook or audiobook';

  @override
  String get linkBookNone => 'No matching book found';

  @override
  String get linkBookSearch => 'Search by title';

  @override
  String get linkBookPick => 'Link to this book?';

  @override
  String linkBookMatchedBy(String reason) {
    return 'Matched by $reason';
  }

  @override
  String get linkReasonAsin => 'ASIN';

  @override
  String get linkReasonIsbn => 'ISBN';

  @override
  String get linkReasonAuthorTitle => 'author and title';

  @override
  String get unlinkBook => 'Unlink';

  @override
  String get listenLinked => 'Listen';

  @override
  String get readLinked => 'Read';

  @override
  String get sectionAndroidAuto => 'Android Auto';

  @override
  String get sectionAdvanced => 'Advanced';

  @override
  String get autoRewindOff => 'Off';

  @override
  String secondsShort(int seconds) {
    return '${seconds}s';
  }

  @override
  String get progressSyncAllSynced => 'Everything is synced';

  @override
  String updatesWaitingToSync(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count updates waiting to sync',
      one: '1 update waiting to sync',
    );
    return '$_temp0';
  }

  @override
  String get batteryExempt =>
      'Exempt from battery optimization — audio won\'t be throttled while the phone is locked';

  @override
  String get batteryRecommended =>
      'Recommended — prevents Android from throttling audio focus and networking while the phone is locked';

  @override
  String get sortTitle => 'Title';

  @override
  String get sortAuthor => 'Author';

  @override
  String get sortDateAdded => 'Date added';

  @override
  String get sortPublishedYear => 'Published year';

  @override
  String get sortDuration => 'Duration';

  @override
  String get sortLastPlayed => 'Last played';

  @override
  String get sortRandom => 'Random';

  @override
  String get filterGenre => 'Genre';

  @override
  String get filterTag => 'Tag';

  @override
  String get filterAuthor => 'Author';

  @override
  String get filterNarrator => 'Narrator';

  @override
  String get filterSeries => 'Series';

  @override
  String get filterLanguage => 'Language';

  @override
  String get filterProgress => 'Progress';

  @override
  String get filterEbook => 'Ebook';

  @override
  String get progressInProgress => 'In progress';

  @override
  String get progressFinished => 'Finished';

  @override
  String get progressNotStarted => 'Not started';

  @override
  String get progressNotFinished => 'Not finished';

  @override
  String get ebookHas => 'Has ebook';

  @override
  String get ebookNone => 'No ebook';

  @override
  String get sectionBooks => 'Books';

  @override
  String get sectionAuthors => 'Authors';

  @override
  String get sectionCollections => 'Collections';

  @override
  String get sectionPlaylists => 'Playlists';

  @override
  String get themeSystem => 'Follow system';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeBlack => 'Black';

  @override
  String get themeSystemShort => 'System';

  @override
  String get skinGlassModernName => 'Glass Modern';

  @override
  String get skinGlassModernDescription =>
      'Frosted glass surfaces over a deep dark background, translucent cards.';

  @override
  String get skinBookshelfName => 'Bookshelf';

  @override
  String get skinBookshelfDescription =>
      'Warm wood and paper tones with book-spine styled covers.';

  @override
  String get sortAscending => 'Ascending';

  @override
  String get sortDescending => 'Descending';

  @override
  String get showEveryBook => 'Show every book';

  @override
  String get collapseSeriesTooltip => 'Collapse series';

  @override
  String get listView => 'List view';

  @override
  String get gridView => 'Grid view';

  @override
  String skinSelectedSuffix(String skin) {
    return '$skin, selected';
  }

  @override
  String get tabHome => 'Home';

  @override
  String get tabSeries => 'Series';

  @override
  String get tabLibrary => 'Library';

  @override
  String get live => 'Live';

  @override
  String get connecting => 'Connecting';

  @override
  String get authFailed => 'Auth failed';

  @override
  String get offline => 'Offline';

  @override
  String get author => 'Author';

  @override
  String get collection => 'Collection';

  @override
  String get playlist => 'Playlist';

  @override
  String get renameCollection => 'Rename collection';

  @override
  String get deleteCollectionTitle => 'Delete collection?';

  @override
  String deleteCollectionMessage(String name) {
    return '\"$name\" will be deleted for everyone on this server.';
  }

  @override
  String get renamePlaylist => 'Rename playlist';

  @override
  String get deletePlaylistTitle => 'Delete playlist?';

  @override
  String deletePlaylistMessage(String name) {
    return '\"$name\" will be deleted.';
  }

  @override
  String get save => 'Save';

  @override
  String get create => 'Create';

  @override
  String get narrators => 'Narrators';

  @override
  String get genres => 'Genres';

  @override
  String get tags => 'Tags';

  @override
  String get nothingMatchesFilter => 'Nothing matches this filter.';

  @override
  String get libraryIsEmpty => 'This library is empty.';

  @override
  String get pause => 'Pause';

  @override
  String sleepTimerTooltipActive(String time) {
    return 'Sleep timer: $time';
  }

  @override
  String get sleepTimerTooltip => 'Sleep timer';

  @override
  String get chapterLabel => 'Chapter';

  @override
  String get bookLabel => 'Book';

  @override
  String trackNumber(int number) {
    return 'Track $number';
  }

  @override
  String speedInputError(Object min, Object max) {
    return 'Enter a number between $min and $max.';
  }

  @override
  String get hideExactSpeed => 'Hide exact speed';

  @override
  String get enterExactSpeed => 'Enter exact speed';

  @override
  String get startTimer => 'Start timer';

  @override
  String get sleepTimerEnded => 'Sleep timer ended';

  @override
  String chapterEndsIn(String time) {
    return 'Chapter ends in $time';
  }

  @override
  String sleepIn(String time) {
    return 'Sleep in $time';
  }

  @override
  String get dailyAverage => 'Daily average';

  @override
  String get bestDay => 'Best day';

  @override
  String get daysListened => 'Days listened';

  @override
  String get currentStreak => 'Current streak';

  @override
  String get thisWeek => 'This week';

  @override
  String get itemsFinished => 'Items finished';

  @override
  String streakDays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get daysActive => 'Days active';

  @override
  String streakDaysShort(int count) {
    return '${count}d';
  }

  @override
  String logEntrySubtitle(String tag, String when) {
    return '$tag · $when';
  }

  @override
  String logEntrySubtitleRepeated(String tag, String when, int count) {
    return '$tag · $when · ×$count';
  }

  @override
  String get enterServerAddress => 'Enter a server address.';

  @override
  String get notAudiobookshelf =>
      'That doesn\'t look like an Audiobookshelf server.';

  @override
  String get serverNotInitialized =>
      'This server has no admin account set up yet — finish setup in a browser first.';

  @override
  String get somethingWentWrong => 'Something went wrong. Try again.';

  @override
  String get couldntReachCheckConnection =>
      'Couldn\'t reach that server — check the address and your connection.';

  @override
  String get couldntConnectCheckServer =>
      'Couldn\'t connect. Check the address and that the server is online.';

  @override
  String serverRespondedWithError(Object code) {
    return 'Server responded with an error ($code). Check the address.';
  }

  @override
  String get couldntReachTryAgain =>
      'Couldn\'t reach that server. Check the address and try again.';

  @override
  String get enterUsername => 'Enter a username.';

  @override
  String get incorrectCredentials => 'Incorrect username or password.';

  @override
  String get lostConnection => 'Lost connection to the server.';

  @override
  String get loginFailed => 'Login failed. Try again.';

  @override
  String get couldntChangePasswordCheckCurrent =>
      'Couldn\'t change your password. Check your current password.';

  @override
  String get passwordChangeNotAllowed =>
      'Your account isn\'t allowed to change its password.';

  @override
  String get tooManyAttempts =>
      'Too many attempts. Wait a minute and try again.';

  @override
  String get couldntChangePassword =>
      'Couldn\'t change your password. Try again.';

  @override
  String get pwEnterCurrent => 'Enter your current password.';

  @override
  String get pwEnterNew => 'Enter a new password.';

  @override
  String pwTooShort(int min) {
    return 'New password must be at least $min characters.';
  }

  @override
  String get pwSame => 'New password must be different from your current one.';

  @override
  String get pwMismatch => 'New passwords don\'t match.';

  @override
  String get cellularStreamTitle => 'Stream over cellular?';

  @override
  String get cellularDownloadTitle => 'Download over cellular?';

  @override
  String get cellularStreamBody =>
      'You\'re on a mobile connection. Streaming will use your data. Your choice is remembered until the app restarts.';

  @override
  String get cellularDownloadBody =>
      'You\'re on a mobile connection. Downloading will use your data. Your choice is remembered until the app restarts.';

  @override
  String get notNow => 'Not now';

  @override
  String get streamAction => 'Stream';

  @override
  String get downloadAction => 'Download';

  @override
  String get cellularStreamBlocked =>
      'Streaming over cellular is off in Settings → Data.';

  @override
  String get cellularDownloadBlocked =>
      'Downloading over cellular is off in Settings → Data.';

  @override
  String get switchAccountTitle => 'Switch account?';

  @override
  String switchAccountWhilePlaying(String server) {
    return 'Playback will stop. Switch to $server?';
  }

  @override
  String get switchAction => 'Switch';

  @override
  String removeAccountTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String removeAccountMessage(String server) {
    return 'Signs out of $server on this device. Downloads from it can be kept or deleted.';
  }

  @override
  String get removeAndDeleteDownloads => 'Remove and delete downloads';

  @override
  String get removeKeepDownloads => 'Remove, keep downloads';

  @override
  String get accounts => 'Accounts';

  @override
  String get menu => 'Menu';

  @override
  String get addServerOrAccount => 'Add server or account';

  @override
  String get manageAccounts => 'Manage accounts';

  @override
  String continueAsAccount(String name) {
    return 'Continue as $name';
  }

  @override
  String get savedAccounts => 'Saved accounts';

  @override
  String get sectionAccount => 'Account';

  @override
  String get askBeforeSwitching => 'Ask before switching while playing';

  @override
  String get askBeforeSwitchingHint =>
      'Switching servers or accounts stops playback';

  @override
  String get showOtherServerDownloads => 'Show downloads from other servers';

  @override
  String get showOtherServerDownloadsHint =>
      'Keep downloaded books from your other servers in the Downloads list';

  @override
  String downloadsFromServer(String server) {
    return 'Downloads from $server';
  }

  @override
  String accountOnServer(String name, String server) {
    return '$name on $server';
  }

  @override
  String get addAccountTitle => 'Add server or account';

  @override
  String get more => 'More';

  @override
  String get readingProgress => 'Reading progress';

  @override
  String get highlight => 'Highlight';

  @override
  String get bookmarkThisPage => 'Bookmark this page';

  @override
  String get bookmarksAndHighlights => 'Bookmarks and highlights';

  @override
  String get highlights => 'Highlights';

  @override
  String get noHighlightsYet =>
      'No highlights yet. Select text and choose Highlight.';

  @override
  String get epubReadingMode => 'Books (EPUB)';

  @override
  String get pdfReadingMode => 'PDF';

  @override
  String get comicReadingMode => 'Comics';

  @override
  String get pagedMode => 'Pages';

  @override
  String get scrollMode => 'Scroll';

  @override
  String get tapToTurnPages => 'Tap screen edges to turn pages';

  @override
  String get keepScreenOn => 'Keep screen on while reading';

  @override
  String get brightness => 'Brightness';

  @override
  String get justifyText => 'Justify text';

  @override
  String get margins => 'Margins';

  @override
  String get marginsSides => 'Left and right margins';

  @override
  String get marginsTopBottom => 'Top and bottom margins';

  @override
  String readingPercent(int percent) {
    return 'Continue reading ($percent%)';
  }
}
