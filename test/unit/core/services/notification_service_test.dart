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

  group('vacation notices', () {
    test('check-ins have an "I\'m back" button, registered at setup', () {
      final category = NotificationService.initializationSettings.iOS!.notificationCategories
          .singleWhere((c) => c.identifier == NotificationService.vacationCategory);
      expect(category.actions.single.identifier, NotificationService.vacationBackAction);
      expect(NotificationService.vacationDetails(canEnd: true).iOS!.categoryIdentifier,
          NotificationService.vacationCategory);
      expect(NotificationService.vacationDetails(canEnd: true).android!.actions!.single.id,
          NotificationService.vacationBackAction);
      expect(NotificationService.vacationDetails(canEnd: false).iOS!.categoryIdentifier, isNull,
          reason: 'the welcome back has nothing to end');
    });

    test('"I\'m back" asks the app to end vacation mode; a tap opens it without picking a habit', () {
      final before = NotificationService.vacationBackRequests.value;
      NotificationService.focusRequests.value = null;
      NotificationService.handleResponse(NotificationService.vacationBackAction, NotificationService.vacationPayload);
      expect(NotificationService.vacationBackRequests.value, before + 1);
      NotificationService.handleResponse(null, NotificationService.vacationPayload);
      expect(NotificationService.vacationBackRequests.value, before + 1);
      expect(NotificationService.focusRequests.value, isNull);
      expect(NotificationService.habitIdFromPayload(NotificationService.vacationPayload), isNull);
    });
  });
}
