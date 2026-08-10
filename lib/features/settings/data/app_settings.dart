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

  Map<String, dynamic> toJson() => {
    'jumpIntervalSeconds': jumpIntervalSeconds,
    'scaleElapsedTimeBySpeed': scaleElapsedTimeBySpeed,
    'allowCellularStreaming': allowCellularStreaming,
    'allowCellularDownloads': allowCellularDownloads,
    'hapticFeedbackEnabled': hapticFeedbackEnabled,
    'keepScreenAwake': keepScreenAwake,
    'lockPortrait': lockPortrait,
    'sleepTimerDefaultMinutes': sleepTimerDefaultMinutes,
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
    );
  }
}
