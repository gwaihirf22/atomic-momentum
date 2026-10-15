import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/streak_warning_settings.dart';

/// App-wide preferences persisted in SharedPreferences.
class SettingsProvider extends ChangeNotifier {
  static const _streakWarningEnabledKey = 'streakWarningEnabled';
  static const _streakWarningLeadHoursKey = 'streakWarningLeadHours';

  final SharedPreferences _prefs;

  SettingsProvider(this._prefs);

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
