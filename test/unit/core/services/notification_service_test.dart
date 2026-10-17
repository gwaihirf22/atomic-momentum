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

  test('setup never asks for permission, so startup is not blocked by the prompt', () {
    for (final darwin in [
      NotificationService.initializationSettings.iOS!,
      NotificationService.initializationSettings.macOS!,
    ]) {
      expect(darwin.requestAlertPermission, isFalse);
      expect(darwin.requestBadgePermission, isFalse);
      expect(darwin.requestSoundPermission, isFalse);
    }
  });
}
