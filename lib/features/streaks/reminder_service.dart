import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/app_database.dart';
import '../../l10n/gen/app_localizations.dart';
import '../auth/data/server_profile_repository.dart' show profileScopedKey;
import '../auth/state/session_controller.dart' show activeProfileIdProvider;
import '../settings/state/settings_providers.dart';
import 'reminder_plan.dart';
import 'streak.dart' show dayKey;
import 'streak_providers.dart';

const _channel = MethodChannel('steeped/reminders');

/// Days a reminder was scheduled for, per profile (last two weeks), used to
/// count ignored reminders.
class ReminderLogStore {
  ReminderLogStore(this._db, this.profileId);

  final AppDatabase _db;
  final String profileId;

  String get _key => profileId.isEmpty
      ? 'reminder_log'
      : profileScopedKey(profileId, 'reminder_log');

  Future<Set<String>> load() async {
    final row = await (_db.select(
      _db.keyValueEntries,
    )..where((t) => t.key.equals(_key))).getSingleOrNull();
    if (row == null) return {};
    try {
      return {...(jsonDecode(row.value) as List<dynamic>).cast<String>()};
    } catch (_) {
      return {};
    }
  }

  Future<void> add(String day) async {
    final all = await load();
    if (!all.add(day)) return;
    final keep = (all.toList()..sort()).reversed.take(14).toList();
    await _db
        .into(_db.keyValueEntries)
        .insertOnConflictUpdate(
          KeyValueEntriesCompanion.insert(key: _key, value: jsonEncode(keep)),
        );
  }
}

AppLocalizations _strings() {
  try {
    return lookupAppLocalizations(PlatformDispatcher.instance.locale);
  } catch (_) {
    return lookupAppLocalizations(const Locale('en'));
  }
}

/// Keeps the Android alarm in step with the streak and the reminder settings:
/// schedules the next reminder, or cancels it when reminders are off, the day
/// is done or there is no streak. Watched once from Home. Alarms do not
/// survive a reboot, so the next app start schedules it again.
final reminderSyncProvider = Provider<void>((ref) {
  if (!Platform.isAndroid) return;
  final settings = ref.watch(appSettingsProvider).valueOrNull;
  final streak = ref.watch(streakProvider).valueOrNull;
  if (settings == null || streak == null) return;
  unawaited(_sync(ref, settings, streak));
});

Future<void> _sync(Ref ref, dynamic settings, dynamic streak) async {
  try {
    final now = DateTime.now();
    final log = ReminderLogStore(
      ref.read(appDatabaseProvider),
      ref.read(activeProfileIdProvider) ?? '',
    );
    final at = nextReminderTime(
      enabled: settings.streakReminder as bool,
      minutesOfDay: settings.streakReminderMinutes as int,
      quietHours: settings.streakReminderQuiet as bool,
      todayDone: streak.todayDone as bool,
      currentStreak: streak.current as int,
      ignoredInARow: ignoredReminders(
        reminded: await log.load(),
        recent: streak.recent as List<bool>,
        today: now,
      ),
      now: now,
    );
    if (at == null) {
      await _channel.invokeMethod<void>('cancel');
      return;
    }
    final l = _strings();
    final unit = (settings.streakWeekly as bool)
        ? l.streakWeeks(streak.current as int)
        : l.streakDays(streak.current as int);
    await _channel.invokeMethod<void>('schedule', {
      'at': at.millisecondsSinceEpoch,
      'title': l.reminderTitle,
      'body': l.streakBanner(unit),
      'channelName': l.reminderChannelName,
    });
    await log.add(dayKey(at));
  } on PlatformException catch (e) {
    debugPrint('[reminder] $e');
  } on MissingPluginException {
    // Not running on a device with the channel (tests).
  }
}

/// Settings "Send a test reminder": one notification in about 5 seconds, using
/// the current streak wording. Does not touch the real reminder's schedule
/// until the next sync, which replaces it.
Future<void> sendTestReminder(int streakDays, {bool weekly = false}) async {
  if (!Platform.isAndroid) return;
  final l = _strings();
  final unit = weekly ? l.streakWeeks(streakDays) : l.streakDays(streakDays);
  await _channel.invokeMethod<void>('schedule', {
    'at': DateTime.now().add(const Duration(seconds: 5)).millisecondsSinceEpoch,
    'title': l.reminderTitle,
    'body': l.streakBanner(unit),
    'channelName': l.reminderChannelName,
  });
}
