/// PLAN.md Phase 9.3: device-local settings (not server-tracked), persisted
/// via the same `KeyValueEntries` JSON-blob pattern as [EreaderSettings].
/// Only settings that actually do something are here — no placeholder
/// toggles wired to nothing.
class AppSettings {
  const AppSettings({
    this.jumpIntervalSeconds = 30,
    this.scaleElapsedTimeBySpeed = false,
    this.allowCellularStreaming = true,
    this.allowCellularDownloads = true,
    this.hapticFeedbackEnabled = true,
    this.keepScreenAwake = false,
    this.lockPortrait = false,
    this.sleepTimerDefaultMinutes = 30,
    this.skinId = 'glassModern',
    this.showTracksTab = false,
    this.showChapterTime = false,
    this.showBookTime = true,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      jumpIntervalSeconds: json['jumpIntervalSeconds'] as int? ?? 30,
      scaleElapsedTimeBySpeed:
          json['scaleElapsedTimeBySpeed'] as bool? ?? false,
      allowCellularStreaming: json['allowCellularStreaming'] as bool? ?? true,
      allowCellularDownloads: json['allowCellularDownloads'] as bool? ?? true,
      hapticFeedbackEnabled: json['hapticFeedbackEnabled'] as bool? ?? true,
      keepScreenAwake: json['keepScreenAwake'] as bool? ?? false,
      lockPortrait: json['lockPortrait'] as bool? ?? false,
      sleepTimerDefaultMinutes:
          json['sleepTimerDefaultMinutes'] as int? ?? 30,
      skinId: json['skinId'] as String? ?? 'glassModern',
      showTracksTab: json['showTracksTab'] as bool? ?? false,
      // Default true/false respectively — matches the screen's original
      // (pre-toggle) look of a single book-relative time row, so upgrading
      // doesn't change anything for someone who's never touched this.
      showChapterTime: json['showChapterTime'] as bool? ?? false,
      showBookTime: json['showBookTime'] as bool? ?? true,
    );
  }

  /// Playback: jump-forward/back interval, applied in [PlaybackController].
  final int jumpIntervalSeconds;

  /// Playback: displays elapsed/remaining time scaled by the current
  /// playback speed on Now Playing — closes the gap noted in PLAN.md 5.6.
  final bool scaleElapsedTimeBySpeed;

  /// Data: whether streaming/downloading is allowed on a metered
  /// connection, checked via `connectivity_plus` before each starts.
  final bool allowCellularStreaming;
  final bool allowCellularDownloads;

  /// User Interface: haptic feedback on key transport actions.
  final bool hapticFeedbackEnabled;

  /// User Interface: keeps the screen on while Now Playing is open.
  final bool keepScreenAwake;

  /// User Interface: locks the whole app to portrait orientation.
  final bool lockPortrait;

  /// Sleep Timer: default duration offered when starting a timer.
  final int sleepTimerDefaultMinutes;

  /// Appearance (PLAN.md Phase 2.4/2.6): the active [Skin.id.name]. Stored
  /// as a string (not the enum directly) so an unrecognized value from an
  /// older/newer app version just falls back to the default in
  /// `skinByName` rather than failing to decode the whole settings blob.
  final String skinId;

  /// User Interface: shows the Chapters/Tracks toggle on Now Playing (a
  /// multi-file book's raw audio-file list, separate from its chapter
  /// markers). **Off by default** — most books are single-file anyway, so
  /// the toggle would just be dead chrome for most listeners most of the
  /// time; opt-in for the minority who want to see the raw track split.
  final bool showTracksTab;

  /// User Interface: whether Now Playing's time row shows chapter-relative
  /// elapsed/remaining time, book-relative (whole-item) time, or both — at
  /// least one is always true, enforced by [TimeDisplayModeSelector]'s
  /// `SegmentedButton` (`emptySelectionAllowed: false`) rather than here,
  /// since a plain data class has no good way to reject an invalid
  /// combination on construction.
  final bool showChapterTime;
  final bool showBookTime;

  Map<String, dynamic> toJson() => {
    'jumpIntervalSeconds': jumpIntervalSeconds,
    'scaleElapsedTimeBySpeed': scaleElapsedTimeBySpeed,
    'allowCellularStreaming': allowCellularStreaming,
    'allowCellularDownloads': allowCellularDownloads,
    'hapticFeedbackEnabled': hapticFeedbackEnabled,
    'keepScreenAwake': keepScreenAwake,
    'lockPortrait': lockPortrait,
    'sleepTimerDefaultMinutes': sleepTimerDefaultMinutes,
    'skinId': skinId,
    'showTracksTab': showTracksTab,
    'showChapterTime': showChapterTime,
    'showBookTime': showBookTime,
  };

  AppSettings copyWith({
    int? jumpIntervalSeconds,
    bool? scaleElapsedTimeBySpeed,
    bool? allowCellularStreaming,
    bool? allowCellularDownloads,
    bool? hapticFeedbackEnabled,
    bool? keepScreenAwake,
    bool? lockPortrait,
    int? sleepTimerDefaultMinutes,
    String? skinId,
    bool? showTracksTab,
    bool? showChapterTime,
    bool? showBookTime,
  }) {
    return AppSettings(
      jumpIntervalSeconds: jumpIntervalSeconds ?? this.jumpIntervalSeconds,
      scaleElapsedTimeBySpeed:
          scaleElapsedTimeBySpeed ?? this.scaleElapsedTimeBySpeed,
      allowCellularStreaming:
          allowCellularStreaming ?? this.allowCellularStreaming,
      allowCellularDownloads:
          allowCellularDownloads ?? this.allowCellularDownloads,
      hapticFeedbackEnabled:
          hapticFeedbackEnabled ?? this.hapticFeedbackEnabled,
      keepScreenAwake: keepScreenAwake ?? this.keepScreenAwake,
      lockPortrait: lockPortrait ?? this.lockPortrait,
      sleepTimerDefaultMinutes:
          sleepTimerDefaultMinutes ?? this.sleepTimerDefaultMinutes,
      skinId: skinId ?? this.skinId,
      showTracksTab: showTracksTab ?? this.showTracksTab,
      showChapterTime: showChapterTime ?? this.showChapterTime,
      showBookTime: showBookTime ?? this.showBookTime,
    );
  }
}
