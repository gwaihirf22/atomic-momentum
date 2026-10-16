import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;

/// Records what would have been shown or scheduled, in place of the OS plugin.
class FakeNotificationsPlugin extends Fake implements FlutterLocalNotificationsPlugin {
  final List<({int id, String? title, String? body})> shown = [];
  final Map<int, ({String? title, String? body, tz.TZDateTime at})> scheduled = {};

  @override
  Future<void> show(int id, String? title, String? body, NotificationDetails? notificationDetails,
      {String? payload}) async {
    shown.add((id: id, title: title, body: body));
  }

  @override
  Future<void> zonedSchedule(
    int id,
    String? title,
    String? body,
    tz.TZDateTime scheduledDate,
    NotificationDetails notificationDetails, {
    required UILocalNotificationDateInterpretation uiLocalNotificationDateInterpretation,
    bool androidAllowWhileIdle = false,
    AndroidScheduleMode? androidScheduleMode,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    scheduled[id] = (title: title, body: body, at: scheduledDate);
  }

  @override
  Future<void> cancel(int id, {String? tag}) async {
    scheduled.remove(id);
  }

  @override
  Future<List<PendingNotificationRequest>> pendingNotificationRequests() async => [
        for (final e in scheduled.entries) PendingNotificationRequest(e.key, e.value.title, e.value.body, null),
      ];

  // No platform-specific implementation: permission reads as unknown
  @override
  T? resolvePlatformSpecificImplementation<T extends FlutterLocalNotificationsPlatform>() => null;
}
