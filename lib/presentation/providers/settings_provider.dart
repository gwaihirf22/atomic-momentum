import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Locale, TimeOfDay, WidgetsBinding;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/copy/greetings.dart';
import '../../core/locale/week_start.dart';
import '../../core/services/notification_service.dart' show NotifyDefaults;
import '../../domain/entities/habit_notify.dart';
import '../../domain/entities/quiet_hours.dart';
import '../../domain/entities/quote.dart';
import '../../domain/entities/streak_warning_settings.dart';

/// The style the habit editor opens in; either can be switched to there.
enum AddHabitStyle {
  /// One sentence with blanks to fill in.
  story,

  /// Three quick steps for a new habit; edits happen on one page.
  builder,
}

/// App-wide preferences persisted in SharedPreferences.
class SettingsProvider extends ChangeNotifier {
  static const _streakWarningEnabledKey = 'streakWarningEnabled';
  static const _streakWarningLeadHoursKey = 'streakWarningLeadHours';
  static const _streakWarningFirstMissKey = 'streakWarningRemindFirstMiss';
  static const _weekStartKey = 'weekStartDay';
  static const _reminderHourKey = 'defaultReminderHour';
  static const _reminderMinuteKey = 'defaultReminderMinute';
  static const _dayStartHourKey = 'dayStartHour';
  static const _dayStartMinuteKey = 'dayStartMinute';
  static const _addHabitStyleKey = 'addHabitStyle';
  static const _notifySoundKey = 'notifySound';
  static const _allowTimeSensitiveKey = 'allowTimeSensitive';
  static const _quietEnabledKey = 'quietHoursEnabled';
  static const _quietStartKey = 'quietHoursStart';
  static const _quietEndKey = 'quietHoursEnd';
  static const _showInspireTabKey = 'showInspireTab';
  static const _playIntroKey = 'playIntro';
  static const _quoteFamiliesOffKey = 'quoteFamiliesOff';
  static const _healthCardDismissedKey = 'healthCardDismissed';
  static const _vacationNoticesKey = 'vacationNotices';
  static const _weeklyReviewKey = 'weeklyReview';
  static const _weeklyReviewHourKey = 'weeklyReviewHour';
  static const _weeklyReviewMinuteKey = 'weeklyReviewMinute';
  static const _greetingsSeenKey = 'greetingsSeen';

  /// The week in review arrives on the week's last evening at this time.
  static const fallbackWeeklyReviewTime = TimeOfDay(hour: 18, minute: 0);

  /// New habits remind at this time unless changed.
  static const fallbackReminderTime = TimeOfDay(hour: 9, minute: 0);

  /// Every key a setting is stored under: the tours' example world copies
  /// them, so it looks the way the person has the app set up. A test checks
  /// every key above is listed.
  static const storedKeys = [
    _streakWarningEnabledKey,
    _streakWarningLeadHoursKey,
    _streakWarningFirstMissKey,
    _weekStartKey,
    _reminderHourKey,
    _reminderMinuteKey,
    _dayStartHourKey,
    _dayStartMinuteKey,
    _addHabitStyleKey,
    _notifySoundKey,
    _allowTimeSensitiveKey,
    _quietEnabledKey,
    _quietStartKey,
    _quietEndKey,
    _showInspireTabKey,
    _playIntroKey,
    _quoteFamiliesOffKey,
    _healthCardDismissedKey,
    _vacationNoticesKey,
    _weeklyReviewKey,
    _weeklyReviewHourKey,
    _weeklyReviewMinuteKey,
    _greetingsSeenKey,
  ];

  final SharedPreferences _prefs;
  final Locale Function() _deviceLocale;

  /// [deviceLocale] defaults to the device's locale; tests can pin a region.
  SettingsProvider(this._prefs, {Locale Function()? deviceLocale})
      : _deviceLocale = deviceLocale ?? _platformLocale;

  /// The device's locale; straight from the platform before the app's
  /// binding exists (a service planning notifications in a plain test).
  static Locale _platformLocale() {
    try {
      return WidgetsBinding.instance.platformDispatcher.locale;
    } on FlutterError {
      return PlatformDispatcher.instance.locale;
    }
  }

  /// The user's choice of first weekday (DateTime.monday..sunday), or null
  /// for Automatic (follow the device's region, like iOS Calendar).
  int? get weekStartOverride => _prefs.getInt(_weekStartKey);

  /// The day the week starts on, for calendars and weekday pickers.
  int get firstDayOfWeek => weekStartOverride ?? regionalFirstDayOfWeek(_deviceLocale());

  /// What Automatic currently means for this device.
  int get regionalFirstDay => regionalFirstDayOfWeek(_deviceLocale());

  Future<void> setWeekStart(int? day) async {
    if (day == null) {
      await _prefs.remove(_weekStartKey);
    } else {
      await _prefs.setInt(_weekStartKey, day);
    }
    notifyListeners();
  }

  /// The time new habits' reminders start at.
  TimeOfDay get defaultReminderTime {
    final hour = _prefs.getInt(_reminderHourKey);
    final minute = _prefs.getInt(_reminderMinuteKey);
    return hour == null || minute == null ? fallbackReminderTime : TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> setDefaultReminderTime(TimeOfDay time) async {
    await _prefs.setInt(_reminderHourKey, time.hour);
    await _prefs.setInt(_reminderMinuteKey, time.minute);
    notifyListeners();
  }

  /// When the person's day starts; the Habits greetings follow it (see
  /// Greetings.partOf), so night shifts get morning greetings on waking.
  TimeOfDay get dayStart {
    final hour = _prefs.getInt(_dayStartHourKey);
    final minute = _prefs.getInt(_dayStartMinuteKey);
    return hour == null || minute == null ? Greetings.defaultDayStart : TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> setDayStart(TimeOfDay time) async {
    await _prefs.setInt(_dayStartHourKey, time.hour);
    await _prefs.setInt(_dayStartMinuteKey, time.minute);
    notifyListeners();
  }

  /// Story until the person picks Builder.
  AddHabitStyle get addHabitStyle {
    final saved = _prefs.getString(_addHabitStyleKey);
    return AddHabitStyle.values.where((s) => s.name == saved).firstOrNull ?? AddHabitStyle.story;
  }

  Future<void> setAddHabitStyle(AddHabitStyle style) async {
    await _prefs.setString(_addHabitStyleKey, style.name);
    notifyListeners();
  }

  /// The sound habits use unless they pick their own (Chime by default).
  NotifySound get notifySound => NotifySound.fromJson(_prefs.getString(_notifySoundKey)) ?? NotifySound.chime;

  Future<void> setNotifySound(NotifySound sound) async {
    await _prefs.setString(_notifySoundKey, sound.name);
    notifyListeners();
  }

  /// Whether habits marked time-sensitive may break through Focus.
  bool get allowTimeSensitive => _prefs.getBool(_allowTimeSensitiveKey) ?? true;

  Future<void> setAllowTimeSensitive(bool allow) async {
    await _prefs.setBool(_allowTimeSensitiveKey, allow);
    notifyListeners();
  }

  /// Whether vacation mode sends its check-ins and welcome back (on until
  /// turned off).
  bool get vacationNotices => _prefs.getBool(_vacationNoticesKey) ?? true;

  Future<void> setVacationNotices(bool on) async {
    await _prefs.setBool(_vacationNoticesKey, on);
    notifyListeners();
  }

  /// Whether the week in review is announced with a notification (on until
  /// turned off; it shows on Insights either way).
  bool get weeklyReview => _prefs.getBool(_weeklyReviewKey) ?? true;

  Future<void> setWeeklyReview(bool on) async {
    await _prefs.setBool(_weeklyReviewKey, on);
    notifyListeners();
  }

  /// When, on the week's last day, the week in review arrives.
  TimeOfDay get weeklyReviewTime {
    final hour = _prefs.getInt(_weeklyReviewHourKey);
    final minute = _prefs.getInt(_weeklyReviewMinuteKey);
    return hour == null || minute == null ? fallbackWeeklyReviewTime : TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> setWeeklyReviewTime(TimeOfDay time) async {
    await _prefs.setInt(_weeklyReviewHourKey, time.hour);
    await _prefs.setInt(_weeklyReviewMinuteKey, time.minute);
    notifyListeners();
  }

  /// The Habits greetings shown lately, so each takes its turn (see
  /// Greetings.remember).
  Set<String> get greetingsSeen => {...?_prefs.getStringList(_greetingsSeenKey)};

  /// Saved quietly: nothing on screen changes with it.
  Future<void> setGreetingsSeen(Set<String> seen) => _prefs.setStringList(_greetingsSeenKey, seen.toList());

  /// Whether the intro plays on a cold launch (on until turned off).
  bool get playIntro => _prefs.getBool(_playIntroKey) ?? true;

  Future<void> setPlayIntro(bool play) async {
    await _prefs.setBool(_playIntroKey, play);
    notifyListeners();
  }

  /// Whether the Inspire tab shows in the tab bar (on until turned off).
  bool get showInspireTab => _prefs.getBool(_showInspireTabKey) ?? true;

  Future<void> setShowInspireTab(bool show) async {
    await _prefs.setBool(_showInspireTabKey, show);
    notifyListeners();
  }

  /// The quote sources turned on (all until some are turned off). Stored as
  /// the ones turned off, so sources added later start on.
  Set<QuoteFamily> get quoteFamilies {
    final off = _prefs.getStringList(_quoteFamiliesOffKey) ?? const [];
    return {for (final family in QuoteFamily.values) if (!off.contains(family.name)) family};
  }

  /// Turns a source on or off; the last one on stays on.
  Future<void> setQuoteFamily(QuoteFamily family, bool on) async {
    final families = quoteFamilies;
    on ? families.add(family) : families.remove(family);
    if (families.isEmpty) return;
    await _prefs.setStringList(_quoteFamiliesOffKey, [
      for (final f in QuoteFamily.values)
        if (!families.contains(f)) f.name,
    ]);
    notifyListeners();
  }

  /// Habits whose page no longer offers "Fill in from Apple Health" (the
  /// person said Not now).
  Set<String> get healthCardDismissed => (_prefs.getStringList(_healthCardDismissedKey) ?? const []).toSet();

  /// Stops offering Health on [habitId]'s page. Ids not in [habitIds] (habits
  /// since deleted) are dropped at the same time.
  Future<void> dismissHealthCard(String habitId, {required Iterable<String> habitIds}) async {
    final existing = habitIds.toSet();
    final dismissed = {...healthCardDismissed.where(existing.contains), habitId};
    await _prefs.setStringList(_healthCardDismissedKey, dismissed.toList()..sort());
    notifyListeners();
  }

  /// What habits fall back to, for the notification scheduler.
  NotifyDefaults get notifyDefaults => NotifyDefaults(sound: notifySound, allowTimeSensitive: allowTimeSensitive);

  /// A nightly window when nothing arrives (off until turned on).
  QuietHours get quietHours {
    TimeOfDay? read(String key) {
      final minutes = _prefs.getInt(key);
      return minutes == null ? null : TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
    }

    return QuietHours(
      enabled: _prefs.getBool(_quietEnabledKey) ?? false,
      start: read(_quietStartKey) ?? QuietHours.defaultStart,
      end: read(_quietEndKey) ?? QuietHours.defaultEnd,
    );
  }

  Future<void> setQuietHours(QuietHours quiet) async {
    await _prefs.setBool(_quietEnabledKey, quiet.enabled);
    await _prefs.setInt(_quietStartKey, quiet.start.hour * 60 + quiet.start.minute);
    await _prefs.setInt(_quietEndKey, quiet.end.hour * 60 + quiet.end.minute);
    notifyListeners();
  }

  StreakWarningSettings get streakWarnings {
    const defaults = StreakWarningSettings.defaults;
    final leadHours = _prefs.getInt(_streakWarningLeadHoursKey);
    return StreakWarningSettings(
      enabled: _prefs.getBool(_streakWarningEnabledKey) ?? defaults.enabled,
      leadTime: leadHours != null ? Duration(hours: leadHours) : defaults.leadTime,
      remindBeforeFirstMiss: _prefs.getBool(_streakWarningFirstMissKey) ?? defaults.remindBeforeFirstMiss,
    );
  }

  Future<void> setRemindBeforeFirstMiss(bool remind) async {
    await _prefs.setBool(_streakWarningFirstMissKey, remind);
    notifyListeners();
  }

  Future<void> setStreakWarningsEnabled(bool enabled) async {
    await _prefs.setBool(_streakWarningEnabledKey, enabled);
    notifyListeners();
  }

  Future<void> setStreakWarningLeadTime(Duration leadTime) async {
    await _prefs.setInt(_streakWarningLeadHoursKey, leadTime.inHours);
    notifyListeners();
  }
}
