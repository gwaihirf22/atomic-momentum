import 'package:flutter/material.dart' show Locale, TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atomic_momentum/domain/entities/streak_warning_settings.dart';
import 'package:atomic_momentum/presentation/providers/settings_provider.dart';

void main() {
  late SettingsProvider settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = SettingsProvider(await SharedPreferences.getInstance());
  });

  test('defaults to warnings on, 4 hours before', () {
    expect(settings.streakWarnings, StreakWarningSettings.defaults);
    expect(settings.streakWarnings.leadTime, const Duration(hours: 4));
  });

  test('persists changes and notifies listeners', () async {
    var notifications = 0;
    settings.addListener(() => notifications++);

    await settings.setStreakWarningsEnabled(false);
    await settings.setStreakWarningLeadTime(const Duration(hours: 24));

    expect(notifications, 2);

    final reloaded = SettingsProvider(await SharedPreferences.getInstance());
    expect(reloaded.streakWarnings.enabled, isFalse);
    expect(reloaded.streakWarnings.leadTime, const Duration(hours: 24));
  });

  test('reminding before a first miss is off by default and is saved', () async {
    expect(settings.streakWarnings.remindBeforeFirstMiss, isFalse);

    await settings.setRemindBeforeFirstMiss(true);

    final reloaded = SettingsProvider(await SharedPreferences.getInstance());
    expect(reloaded.streakWarnings.remindBeforeFirstMiss, isTrue);
  });

  test('the default reminder time starts at 9:00 and is saved', () async {
    expect(settings.defaultReminderTime, const TimeOfDay(hour: 9, minute: 0));
    await settings.setDefaultReminderTime(const TimeOfDay(hour: 19, minute: 15));
    final reloaded = SettingsProvider(await SharedPreferences.getInstance());
    expect(reloaded.defaultReminderTime, const TimeOfDay(hour: 19, minute: 15));
  });

  test('my day starts at 5:00 by default and is saved', () async {
    expect(settings.dayStart, const TimeOfDay(hour: 5, minute: 0));
    await settings.setDayStart(const TimeOfDay(hour: 15, minute: 30));
    final reloaded = SettingsProvider(await SharedPreferences.getInstance());
    expect(reloaded.dayStart, const TimeOfDay(hour: 15, minute: 30));
  });

  group('week start', () {
    Future<SettingsProvider> forRegion(Locale locale) async =>
        SettingsProvider(await SharedPreferences.getInstance(), deviceLocale: () => locale);

    test('automatic follows the device region', () async {
      expect((await forRegion(const Locale('en', 'US'))).firstDayOfWeek, DateTime.sunday);
      expect((await forRegion(const Locale('en', 'GB'))).firstDayOfWeek, DateTime.monday);
      expect((await forRegion(const Locale('en', 'US'))).weekStartOverride, isNull);
    });

    test('a chosen day is saved and can be reset to automatic', () async {
      final us = await forRegion(const Locale('en', 'US'));
      await us.setWeekStart(DateTime.monday);
      expect((await forRegion(const Locale('en', 'US'))).firstDayOfWeek, DateTime.monday);

      await us.setWeekStart(null);
      expect((await forRegion(const Locale('en', 'US'))).firstDayOfWeek, DateTime.sunday);
    });
  });

  test('new habits start in Builder; Story is saved when chosen', () async {
    expect(settings.addHabitStyle, AddHabitStyle.builder);
    var notified = false;
    settings.addListener(() => notified = true);

    await settings.setAddHabitStyle(AddHabitStyle.story);

    expect(notified, isTrue);
    expect(SettingsProvider(await SharedPreferences.getInstance()).addHabitStyle, AddHabitStyle.story);
  });

  test('an unknown saved style falls back to Builder', () async {
    SharedPreferences.setMockInitialValues({'addHabitStyle': 'wizard'});
    expect(SettingsProvider(await SharedPreferences.getInstance()).addHabitStyle, AddHabitStyle.builder);
  });
}
