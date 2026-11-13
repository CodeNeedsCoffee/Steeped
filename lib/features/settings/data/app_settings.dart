/// PLAN.md Phase 9.3: device-local settings (not server-tracked), persisted
/// via the same `KeyValueEntries` JSON-blob pattern as [EreaderSettings].
/// Only settings that actually do something are here — no placeholder
/// toggles wired to nothing.
/// How a cellular (or metered) connection is treated for streaming and
/// downloads. [ask] prompts once per session per action.
enum CellularPolicy {
  always,
  ask,
  never;

  static CellularPolicy parse(Object? raw, {required CellularPolicy fallback}) {
    for (final p in values) {
      if (p.name == raw) return p;
    }
    return fallback;
  }
}

class AppSettings {
  const AppSettings({
    this.jumpBackSeconds = 30,
    this.jumpForwardSeconds = 30,
    this.playbackSpeed = 1.0,
    this.scaleElapsedTimeBySpeed = false,
    this.cellularStreaming = CellularPolicy.always,
    this.cellularDownloads = CellularPolicy.always,
    this.treatMeteredAsCellular = false,
    this.confirmSwitchWhilePlaying = true,
    this.showOtherServerDownloads = true,
    this.maskServerAddress = false,
    this.allowSeekOnMediaControls = true,
    this.hapticFeedbackEnabled = true,
    this.keepScreenAwake = false,
    this.lockPortrait = false,
    this.sleepTimerDefaultMinutes = 30,
    this.rememberLibrarySection = true,
    this.collapseSeries = false,
    this.autoBrowseLimit = 40,
    this.autoSeriesNewestFirst = false,
    this.showSyncIndicator = true,
    this.autoRewindSeconds = 0,
    this.autoRewindScale = false,
    this.sleepFadeOut = true,
    this.sleepFadeSeconds = 10,
    this.linkSyncToAudio = 'estimated',
    this.linkSyncToEbook = 'estimated',
    this.linkSwitchMode = 'ask',
    this.linkFollow = true,
    this.linkDock = true,
    this.showStreak = true,
    this.streakGoalMinutes = 0,
    this.streakForgive = true,
    this.streakWeekly = false,
    this.streakReminder = false,
    this.streakReminderMinutes = 19 * 60,
    this.streakReminderQuiet = true,
    this.sleepChime = false,
    this.sleepExtendMinutes = 5,
    this.sleepAutoWindow = false,
    this.sleepWindowStartMinutes = 1320,
    this.sleepWindowEndMinutes = 360,
    this.skinId = 'glassModern',
    this.themeVariant = 'dark',
    this.showTracksTab = false,
    this.showChapterTime = false,
    this.showBookTime = true,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      // Pre-split installs stored one `jumpIntervalSeconds`; both sides fall
      // back to it so nobody's configured value resets.
      jumpBackSeconds:
          json['jumpBackSeconds'] as int? ??
          json['jumpIntervalSeconds'] as int? ??
          30,
      jumpForwardSeconds:
          json['jumpForwardSeconds'] as int? ??
          json['jumpIntervalSeconds'] as int? ??
          30,
      playbackSpeed: (json['playbackSpeed'] as num?)?.toDouble() ?? 1.0,
      scaleElapsedTimeBySpeed:
          json['scaleElapsedTimeBySpeed'] as bool? ?? false,
      // Old installs stored bools: true -> always, false -> never.
      cellularStreaming: _policyFrom(
        json['cellularStreaming'],
        json['allowCellularStreaming'],
      ),
      cellularDownloads: _policyFrom(
        json['cellularDownloads'],
        json['allowCellularDownloads'],
      ),
      treatMeteredAsCellular: json['treatMeteredAsCellular'] as bool? ?? false,
      confirmSwitchWhilePlaying:
          json['confirmSwitchWhilePlaying'] as bool? ?? true,
      showOtherServerDownloads:
          json['showOtherServerDownloads'] as bool? ?? true,
      maskServerAddress: json['maskServerAddress'] as bool? ?? false,
      allowSeekOnMediaControls:
          json['allowSeekOnMediaControls'] as bool? ?? true,
      hapticFeedbackEnabled: json['hapticFeedbackEnabled'] as bool? ?? true,
      keepScreenAwake: json['keepScreenAwake'] as bool? ?? false,
      lockPortrait: json['lockPortrait'] as bool? ?? false,
      sleepTimerDefaultMinutes: json['sleepTimerDefaultMinutes'] as int? ?? 30,
      rememberLibrarySection: json['rememberLibrarySection'] as bool? ?? true,
      collapseSeries: json['collapseSeries'] as bool? ?? false,
      autoBrowseLimit: json['autoBrowseLimit'] as int? ?? 40,
      autoSeriesNewestFirst: json['autoSeriesNewestFirst'] as bool? ?? false,
      showSyncIndicator: json['showSyncIndicator'] as bool? ?? true,
      autoRewindSeconds: json['autoRewindSeconds'] as int? ?? 0,
      autoRewindScale: json['autoRewindScale'] as bool? ?? false,
      sleepFadeOut: json['sleepFadeOut'] as bool? ?? true,
      sleepFadeSeconds: json['sleepFadeSeconds'] as int? ?? 10,
      // One setting used to cover both directions.
      linkSyncToAudio:
          json['linkSyncToAudio'] as String? ??
          json['linkSyncMode'] as String? ??
          'estimated',
      linkSyncToEbook:
          json['linkSyncToEbook'] as String? ??
          json['linkSyncMode'] as String? ??
          'estimated',
      linkSwitchMode: json['linkSwitchMode'] as String? ?? 'ask',
      linkFollow: json['linkFollow'] as bool? ?? true,
      linkDock: json['linkDock'] as bool? ?? true,
      showStreak: json['showStreak'] as bool? ?? true,
      streakGoalMinutes: json['streakGoalMinutes'] as int? ?? 0,
      streakForgive: json['streakForgive'] as bool? ?? true,
      streakWeekly: json['streakWeekly'] as bool? ?? false,
      streakReminder: json['streakReminder'] as bool? ?? false,
      streakReminderMinutes: json['streakReminderMinutes'] as int? ?? 19 * 60,
      streakReminderQuiet: json['streakReminderQuiet'] as bool? ?? true,
      sleepChime: json['sleepChime'] as bool? ?? false,
      sleepExtendMinutes: json['sleepExtendMinutes'] as int? ?? 5,
      sleepAutoWindow: json['sleepAutoWindow'] as bool? ?? false,
      sleepWindowStartMinutes: json['sleepWindowStartMinutes'] as int? ?? 1320,
      sleepWindowEndMinutes: json['sleepWindowEndMinutes'] as int? ?? 360,
      skinId: json['skinId'] as String? ?? 'glassModern',
      themeVariant: json['themeVariant'] as String? ?? 'dark',
      showTracksTab: json['showTracksTab'] as bool? ?? false,
      // Default true/false respectively — matches the screen's original
      // (pre-toggle) look of a single book-relative time row, so upgrading
      // doesn't change anything for someone who's never touched this.
      showChapterTime: json['showChapterTime'] as bool? ?? false,
      showBookTime: json['showBookTime'] as bool? ?? true,
    );
  }

  static CellularPolicy _policyFrom(Object? raw, Object? legacyBool) {
    if (raw != null) {
      return CellularPolicy.parse(raw, fallback: CellularPolicy.always);
    }
    if (legacyBool is bool) {
      return legacyBool ? CellularPolicy.always : CellularPolicy.never;
    }
    return CellularPolicy.always;
  }

  /// Playback: jump-back / jump-forward lengths, applied in
  /// [PlaybackController] and the lock-screen skip buttons.
  final int jumpBackSeconds;
  final int jumpForwardSeconds;

  /// Playback: last speed the user picked, re-applied to every newly
  /// loaded item so it survives closing and reopening the app.
  final double playbackSpeed;

  /// Playback: displays elapsed/remaining time scaled by the current
  /// playback speed on Now Playing — closes the gap noted in PLAN.md 5.6.
  final bool scaleElapsedTimeBySpeed;

  /// Data: what to do when streaming/downloading would use cellular,
  /// checked via `connectivity_plus` before each starts.
  final CellularPolicy cellularStreaming;
  final CellularPolicy cellularDownloads;

  /// Data: apply the cellular policy to metered Wi-Fi (a phone hotspot) too.
  final bool treatMeteredAsCellular;

  /// Account: ask before switching servers/accounts while something is
  /// playing; list downloads that came from other servers too.
  final bool confirmSwitchWhilePlaying;
  final bool showOtherServerDownloads;

  /// Account: shows the server address as dots until tapped.
  final bool maskServerAddress;

  /// Playback: whether lock-screen/notification controls expose a seek bar.
  final bool allowSeekOnMediaControls;

  /// User Interface: haptic feedback on key transport actions.
  final bool hapticFeedbackEnabled;

  /// User Interface: keeps the screen on while Now Playing is open.
  final bool keepScreenAwake;

  /// User Interface: locks the whole app to portrait orientation.
  final bool lockPortrait;

  /// Sleep Timer: default duration offered when starting a timer.
  final int sleepTimerDefaultMinutes;

  /// Library: reopen the last Books/Authors/Collections/Playlists section;
  /// fold each series into a single tile in the Books grid.
  final bool rememberLibrarySection;
  final bool collapseSeries;

  /// Android Auto: how many entries a browse list holds, and whether a
  /// series lists its newest book first.
  final int autoBrowseLimit;
  final bool autoSeriesNewestFirst;

  /// Advanced: show the badge for progress updates still waiting to sync.
  final bool showSyncIndicator;

  /// Playback: seconds to rewind on resume (0 = off); optionally scaled up
  /// after long pauses.
  final int autoRewindSeconds;
  final bool autoRewindScale;

  /// Sleep Timer: fade the volume over the last [sleepFadeSeconds], play a
  /// chime 30 seconds before the pause, how far "+" extends, and an
  /// automatic timer when playback starts inside a daily window (minutes
  /// since midnight; the window may cross midnight).
  final bool sleepFadeOut;
  final int sleepFadeSeconds;

  /// Linked ebook/audiobook: how a switch finds the matching spot. A
  /// `SyncMode` name: `off` or `estimated` (`precise` is added with J6).
  /// How a switch from the ebook finds its place in the audiobook, and from
  /// the audiobook its place in the ebook: off, estimated or precise, each
  /// way on its own.
  final String linkSyncToAudio;
  final String linkSyncToEbook;

  /// What the Listen/Read buttons do: ask, switch, or both (listen while
  /// reading / read along).
  final String linkSwitchMode;

  /// Scroll the page to follow the audio when listening while reading.
  final bool linkFollow;

  /// Show the player strip in the reader for the linked audiobook.
  final bool linkDock;

  /// Streaks: show the Home chip; the daily bar in minutes (0 = any activity);
  /// forgive one missed day a week; count weeks instead of days.
  final bool showStreak;
  final int streakGoalMinutes;
  final bool streakForgive;
  final bool streakWeekly;

  /// Streak reminder (Android, opt-in): a local notification at
  /// [streakReminderMinutes] after midnight, skipping quiet hours (10pm-8am).
  final bool streakReminder;
  final int streakReminderMinutes;
  final bool streakReminderQuiet;
  final bool sleepChime;
  final int sleepExtendMinutes;
  final bool sleepAutoWindow;
  final int sleepWindowStartMinutes;
  final int sleepWindowEndMinutes;

  /// Appearance (PLAN.md Phase 2.4/2.6): the active [Skin.id.name]. Stored
  /// as a string (not the enum directly) so an unrecognized value from an
  /// older/newer app version just falls back to the default in
  /// `skinByName` rather than failing to decode the whole settings blob.
  final String skinId;

  /// Appearance: the `ThemeVariant` name (system/light/dark/black). Kept as
  /// a string for the same unrecognised-value reason as [skinId]; the
  /// default is today's dark look.
  final String themeVariant;

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
    'jumpBackSeconds': jumpBackSeconds,
    'jumpForwardSeconds': jumpForwardSeconds,
    'playbackSpeed': playbackSpeed,
    'scaleElapsedTimeBySpeed': scaleElapsedTimeBySpeed,
    'cellularStreaming': cellularStreaming.name,
    'cellularDownloads': cellularDownloads.name,
    'treatMeteredAsCellular': treatMeteredAsCellular,
    'confirmSwitchWhilePlaying': confirmSwitchWhilePlaying,
    'showOtherServerDownloads': showOtherServerDownloads,
    'maskServerAddress': maskServerAddress,
    'allowSeekOnMediaControls': allowSeekOnMediaControls,
    'hapticFeedbackEnabled': hapticFeedbackEnabled,
    'keepScreenAwake': keepScreenAwake,
    'lockPortrait': lockPortrait,
    'sleepTimerDefaultMinutes': sleepTimerDefaultMinutes,
    'rememberLibrarySection': rememberLibrarySection,
    'collapseSeries': collapseSeries,
    'autoBrowseLimit': autoBrowseLimit,
    'autoSeriesNewestFirst': autoSeriesNewestFirst,
    'showSyncIndicator': showSyncIndicator,
    'autoRewindSeconds': autoRewindSeconds,
    'autoRewindScale': autoRewindScale,
    'sleepFadeOut': sleepFadeOut,
    'sleepFadeSeconds': sleepFadeSeconds,
    'linkSyncToAudio': linkSyncToAudio,
    'linkSyncToEbook': linkSyncToEbook,
    'linkSwitchMode': linkSwitchMode,
    'linkFollow': linkFollow,
    'linkDock': linkDock,
    'showStreak': showStreak,
    'streakGoalMinutes': streakGoalMinutes,
    'streakForgive': streakForgive,
    'streakWeekly': streakWeekly,
    'streakReminder': streakReminder,
    'streakReminderMinutes': streakReminderMinutes,
    'streakReminderQuiet': streakReminderQuiet,
    'sleepChime': sleepChime,
    'sleepExtendMinutes': sleepExtendMinutes,
    'sleepAutoWindow': sleepAutoWindow,
    'sleepWindowStartMinutes': sleepWindowStartMinutes,
    'sleepWindowEndMinutes': sleepWindowEndMinutes,
    'skinId': skinId,
    'themeVariant': themeVariant,
    'showTracksTab': showTracksTab,
    'showChapterTime': showChapterTime,
    'showBookTime': showBookTime,
  };

  AppSettings copyWith({
    int? jumpBackSeconds,
    int? jumpForwardSeconds,
    double? playbackSpeed,
    bool? scaleElapsedTimeBySpeed,
    CellularPolicy? cellularStreaming,
    CellularPolicy? cellularDownloads,
    bool? treatMeteredAsCellular,
    bool? confirmSwitchWhilePlaying,
    bool? showOtherServerDownloads,
    bool? maskServerAddress,
    bool? allowSeekOnMediaControls,
    bool? hapticFeedbackEnabled,
    bool? keepScreenAwake,
    bool? lockPortrait,
    int? sleepTimerDefaultMinutes,
    bool? rememberLibrarySection,
    bool? collapseSeries,
    int? autoBrowseLimit,
    bool? autoSeriesNewestFirst,
    bool? showSyncIndicator,
    int? autoRewindSeconds,
    bool? autoRewindScale,
    bool? sleepFadeOut,
    int? sleepFadeSeconds,
    String? linkSyncToAudio,
    String? linkSyncToEbook,
    String? linkSwitchMode,
    bool? linkFollow,
    bool? linkDock,
    bool? showStreak,
    int? streakGoalMinutes,
    bool? streakForgive,
    bool? streakWeekly,
    bool? streakReminder,
    int? streakReminderMinutes,
    bool? streakReminderQuiet,
    bool? sleepChime,
    int? sleepExtendMinutes,
    bool? sleepAutoWindow,
    int? sleepWindowStartMinutes,
    int? sleepWindowEndMinutes,
    String? skinId,
    String? themeVariant,
    bool? showTracksTab,
    bool? showChapterTime,
    bool? showBookTime,
  }) {
    return AppSettings(
      jumpBackSeconds: jumpBackSeconds ?? this.jumpBackSeconds,
      jumpForwardSeconds: jumpForwardSeconds ?? this.jumpForwardSeconds,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      scaleElapsedTimeBySpeed:
          scaleElapsedTimeBySpeed ?? this.scaleElapsedTimeBySpeed,
      cellularStreaming: cellularStreaming ?? this.cellularStreaming,
      cellularDownloads: cellularDownloads ?? this.cellularDownloads,
      treatMeteredAsCellular:
          treatMeteredAsCellular ?? this.treatMeteredAsCellular,
      confirmSwitchWhilePlaying:
          confirmSwitchWhilePlaying ?? this.confirmSwitchWhilePlaying,
      showOtherServerDownloads:
          showOtherServerDownloads ?? this.showOtherServerDownloads,
      maskServerAddress: maskServerAddress ?? this.maskServerAddress,
      allowSeekOnMediaControls:
          allowSeekOnMediaControls ?? this.allowSeekOnMediaControls,
      hapticFeedbackEnabled:
          hapticFeedbackEnabled ?? this.hapticFeedbackEnabled,
      keepScreenAwake: keepScreenAwake ?? this.keepScreenAwake,
      lockPortrait: lockPortrait ?? this.lockPortrait,
      sleepTimerDefaultMinutes:
          sleepTimerDefaultMinutes ?? this.sleepTimerDefaultMinutes,
      rememberLibrarySection:
          rememberLibrarySection ?? this.rememberLibrarySection,
      collapseSeries: collapseSeries ?? this.collapseSeries,
      autoBrowseLimit: autoBrowseLimit ?? this.autoBrowseLimit,
      autoSeriesNewestFirst:
          autoSeriesNewestFirst ?? this.autoSeriesNewestFirst,
      showSyncIndicator: showSyncIndicator ?? this.showSyncIndicator,
      autoRewindSeconds: autoRewindSeconds ?? this.autoRewindSeconds,
      autoRewindScale: autoRewindScale ?? this.autoRewindScale,
      sleepFadeOut: sleepFadeOut ?? this.sleepFadeOut,
      sleepFadeSeconds: sleepFadeSeconds ?? this.sleepFadeSeconds,
      linkSyncToAudio: linkSyncToAudio ?? this.linkSyncToAudio,
      linkSyncToEbook: linkSyncToEbook ?? this.linkSyncToEbook,
      linkSwitchMode: linkSwitchMode ?? this.linkSwitchMode,
      linkFollow: linkFollow ?? this.linkFollow,
      linkDock: linkDock ?? this.linkDock,
      showStreak: showStreak ?? this.showStreak,
      streakGoalMinutes: streakGoalMinutes ?? this.streakGoalMinutes,
      streakForgive: streakForgive ?? this.streakForgive,
      streakWeekly: streakWeekly ?? this.streakWeekly,
      streakReminder: streakReminder ?? this.streakReminder,
      streakReminderMinutes:
          streakReminderMinutes ?? this.streakReminderMinutes,
      streakReminderQuiet: streakReminderQuiet ?? this.streakReminderQuiet,
      sleepChime: sleepChime ?? this.sleepChime,
      sleepExtendMinutes: sleepExtendMinutes ?? this.sleepExtendMinutes,
      sleepAutoWindow: sleepAutoWindow ?? this.sleepAutoWindow,
      sleepWindowStartMinutes:
          sleepWindowStartMinutes ?? this.sleepWindowStartMinutes,
      sleepWindowEndMinutes:
          sleepWindowEndMinutes ?? this.sleepWindowEndMinutes,
      skinId: skinId ?? this.skinId,
      themeVariant: themeVariant ?? this.themeVariant,
      showTracksTab: showTracksTab ?? this.showTracksTab,
      showChapterTime: showChapterTime ?? this.showChapterTime,
      showBookTime: showBookTime ?? this.showBookTime,
    );
  }
}
