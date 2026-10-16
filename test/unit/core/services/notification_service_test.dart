import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:atomic_momentum/core/services/notification_service.dart';

void main() {
  // Needed before any getLocation call, including those in group bodies
  tzdata.initializeTimeZones();

  group('configureLocalTimeZone', () {
    tearDown(() => tz.setLocalLocation(tz.UTC));

    test('sets tz.local to the device timezone instead of leaving it UTC', () async {
      NotificationService.timezoneResolver = () async => 'America/Los_Angeles';
      await NotificationService.configureLocalTimeZone();
      expect(tz.local.name, 'America/Los_Angeles');
    });

    test('falls back to UTC if the timezone cannot be resolved', () async {
      NotificationService.timezoneResolver = () async => throw Exception('no plugin');
      await NotificationService.configureLocalTimeZone();
      expect(tz.local.name, 'UTC');
    });
  });

  group('nextOccurrence', () {
    final la = tz.getLocation('America/Los_Angeles');
    const nineAm = TimeOfDay(hour: 9, minute: 0);

    // 2026-10-14 is a Wednesday
    test('fires at 9am local time, not 9am UTC', () {
      final now = tz.TZDateTime(la, 2026, 10, 14, 7, 0);
      final next = NotificationService.nextOccurrence(dayOfWeek: DateTime.wednesday, timeOfDay: nineAm, now: now);

      expect(next.hour, 9);
      expect(next.day, 14);
      expect(next.toUtc().hour, 16, reason: '9am PDT is 16:00 UTC');
    });

    test('moves to next week once today\'s time has passed', () {
      final now = tz.TZDateTime(la, 2026, 10, 14, 10, 0);
      final next = NotificationService.nextOccurrence(dayOfWeek: DateTime.wednesday, timeOfDay: nineAm, now: now);

      expect(next, tz.TZDateTime(la, 2026, 10, 21, 9, 0));
    });

    test('keeps 9am across the end of daylight saving time', () {
      // US DST ends Sunday 2026-11-01
      final now = tz.TZDateTime(la, 2026, 10, 30, 12, 0);
      final next = NotificationService.nextOccurrence(dayOfWeek: DateTime.monday, timeOfDay: nineAm, now: now);

      expect(next.day, 2);
      expect(next.month, 11);
      expect(next.hour, 9);
    });
  });
}
