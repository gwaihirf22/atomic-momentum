import 'package:flutter/material.dart' show Locale, TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atomic_momentum/domain/entities/quote.dart';
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

  test('the habit editor opens in Story; Builder is saved when chosen', () async {
    expect(settings.addHabitStyle, AddHabitStyle.story);
    var notified = false;
    settings.addListener(() => notified = true);

    await settings.setAddHabitStyle(AddHabitStyle.builder);

    expect(notified, isTrue);
    expect(SettingsProvider(await SharedPreferences.getInstance()).addHabitStyle, AddHabitStyle.builder);
  });

  test('an unknown saved style falls back to Story', () async {
    SharedPreferences.setMockInitialValues({'addHabitStyle': 'wizard'});
    expect(SettingsProvider(await SharedPreferences.getInstance()).addHabitStyle, AddHabitStyle.story);
  });

  test('the Inspire tab is on until turned off, and stays off', () async {
    expect(settings.showInspireTab, isTrue);
    await settings.setShowInspireTab(false);
    expect(SettingsProvider(await SharedPreferences.getInstance()).showInspireTab, isFalse);
  });

  test('every quote source starts on; turned off ones stay off; the last one stays on', () async {
    expect(settings.quoteFamilies, QuoteFamily.values.toSet());
    var notified = 0;
    settings.addListener(() => notified++);

    await settings.setQuoteFamily(QuoteFamily.scripture, false);
    expect(settings.quoteFamilies, isNot(contains(QuoteFamily.scripture)));
    final reloaded = SettingsProvider(await SharedPreferences.getInstance());
    expect(reloaded.quoteFamilies, QuoteFamily.values.toSet()..remove(QuoteFamily.scripture));

    for (final family in QuoteFamily.values.where((f) => f != QuoteFamily.mine)) {
      await settings.setQuoteFamily(family, false);
    }
    expect(settings.quoteFamilies, {QuoteFamily.mine});
    await settings.setQuoteFamily(QuoteFamily.mine, false);
    expect(settings.quoteFamilies, {QuoteFamily.mine}, reason: 'one source always stays on');

    await settings.setQuoteFamily(QuoteFamily.scripture, true);
    expect(settings.quoteFamilies, {QuoteFamily.mine, QuoteFamily.scripture});
    // One off, each of the others off (the last refused), one back on
    expect(notified, QuoteFamily.values.length + 1);
  });

  test('unknown stored quote sources are ignored', () async {
    SharedPreferences.setMockInitialValues({'quoteFamiliesOff': ['stoic', 'gone']});
    expect(SettingsProvider(await SharedPreferences.getInstance()).quoteFamilies,
        QuoteFamily.values.toSet()..remove(QuoteFamily.stoic));
  });

  test('sources added in an update start on, even for people who turned others off', () async {
    SharedPreferences.setMockInitialValues({'quoteFamiliesOff': ['scripture']});
    final families = SettingsProvider(await SharedPreferences.getInstance()).quoteFamilies;
    expect(families, containsAll([QuoteFamily.puritans, QuoteFamily.thinkers]));
    expect(families, isNot(contains(QuoteFamily.scripture)));
  });

  test('the launch intro plays until turned off, and stays off', () async {
    expect(settings.playIntro, isTrue);
    await settings.setPlayIntro(false);
    expect(SettingsProvider(await SharedPreferences.getInstance()).playIntro, isFalse);
  });
}
