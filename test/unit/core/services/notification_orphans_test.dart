import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:atomic_momentum/core/services/notification_service.dart';

import '../../../helpers/fake_notifications_plugin.dart';

/// Habits that went without being deleted (a year of use loaded or put back)
/// mustn't leave their streak warnings behind.
void main() {
  late FakeNotificationsPlugin plugin;

  setUpAll(tzdata.initializeTimeZones);

  setUp(() {
    plugin = FakeNotificationsPlugin();
    NotificationService.debugOverride(plugin: plugin);
  });

  tearDown(NotificationService.debugReset);

  Future<void> pending(int id, String? payload) => plugin.zonedSchedule(
        id,
        'title',
        'body',
        tz.TZDateTime.now(tz.UTC).add(const Duration(hours: 1)),
        const NotificationDetails(),
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );

  test('cancels only the streak warnings of habits that are gone', () async {
    await pending(1, 'kept'); // a warning for a habit still there
    await pending(2, 'gone'); // a warning for a habit that's gone
    await pending(3, 'gone'); // its other kind of warning
    await pending(4, '${NotificationService.reminderPayloadPrefix}gone'); // reminders have their own clean-up
    await pending(NotificationService.habitTapTestNotificationId, 'gone'); // the tester's tap test
    await pending(NotificationService.testNotificationId, NotificationService.testPayload);
    await pending(7, null);

    await NotificationService.cancelStreakWarningsExcept({'kept'});

    expect(plugin.scheduled.keys, unorderedEquals([
      1,
      4,
      NotificationService.habitTapTestNotificationId,
      NotificationService.testNotificationId,
      7,
    ]));
  });
}
