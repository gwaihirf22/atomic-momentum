import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Locale, WidgetsBinding;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/locale/week_start.dart';
import '../../domain/entities/streak_warning_settings.dart';

/// App-wide preferences persisted in SharedPreferences.
class SettingsProvider extends ChangeNotifier {
  static const _streakWarningEnabledKey = 'streakWarningEnabled';
  static const _streakWarningLeadHoursKey = 'streakWarningLeadHours';
  static const _weekStartKey = 'weekStartDay';

  final SharedPreferences _prefs;
  final Locale Function() _deviceLocale;

  /// [deviceLocale] defaults to the device's locale; tests can pin a region.
  SettingsProvider(this._prefs, {Locale Function()? deviceLocale})
      : _deviceLocale = deviceLocale ?? (() => WidgetsBinding.instance.platformDispatcher.locale);

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

  StreakWarningSettings get streakWarnings {
    const defaults = StreakWarningSettings.defaults;
    final leadHours = _prefs.getInt(_streakWarningLeadHoursKey);
    return StreakWarningSettings(
      enabled: _prefs.getBool(_streakWarningEnabledKey) ?? defaults.enabled,
      leadTime: leadHours != null ? Duration(hours: leadHours) : defaults.leadTime,
    );
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
