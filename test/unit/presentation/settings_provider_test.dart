import 'dart:ui' show Locale;
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
}
