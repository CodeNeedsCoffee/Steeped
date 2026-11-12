# Changelog

Notable changes to Steeped, newest first. Versions follow `pubspec.yaml` (`MAJOR.MINOR.PATCH+BUILD`; see
[RELEASING.md](RELEASING.md)). Keep **Unreleased** current as work lands, and rename it to the version at release.

## Unreleased

### Added
- **Linked books:** link an ebook and its audiobook (matched by ASIN, then ISBN, then author and title, with a manual
  search) and switch between them, landing at the matching spot (Settings -> Linked books: Off or Estimated). Read and
  Listen from the book page, the EPUB/PDF/comic readers and Now Playing.
- **Streaks:** one streak for listening and reading, a Home chip (dimmed 0 when there is none), a 7-day dot row and
  longest streak on Stats, an evening at-risk banner, milestone messages, and Settings for the daily bar, forgiveness
  and weekly mode. Reading time is recorded on the device only.
- **Streak reminders (Android):** an optional daily notification, off by default, with quiet hours and a test button.
- **Ebook reader:** search in the book, time left, a Listen action, and EPUBs whose chapters are split across files no
  longer show only headings.
- **Library icons** from the server in the library picker; one **menu** for Account, Search, Downloads and Settings.
- Reading positions that fail to upload are retried (offline queue).

### Changed
- Home bar: the Live badge no longer shows the network type (and its setting is gone); the library picker is icon-only
  when closed.
- "Play all" skips ebook-only books; descriptions show as plain text; the Play button is hidden on ebook-only items.
- The book page refreshes its progress after playback (a rewound book no longer says "Finished").
- Reader settings controls line up at the right edge.

### Fixed
- Stuck mini-player header on older servers; ebook readers marking an audiobook finished; ebook resume landing at the top.
