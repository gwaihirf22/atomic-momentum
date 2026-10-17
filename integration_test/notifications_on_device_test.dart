import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:atomic_momentum/core/services/notification_service.dart';
import 'package:atomic_momentum/core/services/reminder_service.dart';
import 'package:atomic_momentum/domain/services/reminder_planner.dart';
import 'package:atomic_momentum/domain/services/streak_warning_planner.dart';

/// What the simulator in test/simulation can't prove: that a real iPhone
/// accepts our notifications and shows them. Uses the real plugin and the
/// real iOS notification center, with times a few seconds ahead.
///
/// Run by hand on each simulator (Momentum must be allowed to notify):
///   tool/device_notification_check.sh "iPhone 17 Pro"
/// Not `flutter test integration_test`: that uninstalls the app afterwards,
/// deleting its habits. The script puts the real app back and opens it,
/// which reschedules the reminders this check clears.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const habitId = 'on-device-check';

  testWidgets('iOS accepts, cancels and delivers our reminders and streak warnings', (tester) async {
    await tester.runAsync(() async {
      await NotificationService.initialize();
      expect(await NotificationService.permissionStatus(), NotificationPermission.granted,
          reason: 'Open Momentum on this simulator once and tap Allow, then run again');

      final plugin = FlutterLocalNotificationsPlugin();
      final scheduler = LocalNotificationReminderScheduler();
      final start = DateTime.now();

      final soon = PlannedReminder(
        habitId: habitId,
        at: start.add(const Duration(seconds: 6)),
        title: 'Momentum check',
        body: 'A reminder, 6 seconds after the test started',
      );
      final later = PlannedReminder(
        habitId: habitId,
        at: start.add(const Duration(minutes: 10)),
        title: 'Momentum check',
        body: 'Cancelled before it fires',
      );
      final warning = StreakWarning(
        at: start.add(const Duration(seconds: 8)),
        title: "Don't miss twice: Momentum check",
        body: 'A streak warning, 8 seconds after the test started',
      );

      await scheduler.schedule(soon);
      await scheduler.schedule(later);
      await NotificationService.scheduleStreakWarning(habitId, warning);

      // Pending, with the ids and payloads the app finds them by
      var pending = await NotificationService.getPendingNotifications();
      final soonId = LocalNotificationReminderScheduler.reminderId(soon);
      final laterId = LocalNotificationReminderScheduler.reminderId(later);
      PendingNotificationRequest? find(int id) => pending.where((p) => p.id == id).firstOrNull;
      expect(find(soonId)?.payload, 'reminder|$habitId');
      expect(find(soonId)?.body, soon.body);
      expect(find(laterId), isNotNull);
      final warningRequest = pending.where((p) => p.payload == habitId).single;
      expect(warningRequest.title, warning.title);

      // Replacing reminders removes them all and leaves the warning
      await NotificationService.cancelPendingReminders();
      pending = await NotificationService.getPendingNotifications();
      expect(pending.where((p) => p.payload?.startsWith('reminder|') ?? false), isEmpty);
      expect(pending.where((p) => p.payload == habitId), hasLength(1));

      // Schedule the soon one again, then let both fire
      await scheduler.schedule(soon);
      await Future<void>.delayed(start.add(const Duration(seconds: 12)).difference(DateTime.now()));

      pending = await NotificationService.getPendingNotifications();
      expect(find(soonId), isNull, reason: 'delivered, so no longer pending');
      expect(pending.where((p) => p.payload == habitId), isEmpty);

      final shown = await plugin.getActiveNotifications();
      expect(shown.map((n) => n.body), containsAll([soon.body, warning.body]),
          reason: 'iOS delivered both to Notification Center');

      // Clean up what this test showed
      for (final n in shown) {
        if (n.body == soon.body || n.body == warning.body) await plugin.cancel(n.id!);
      }
    });
  });
}
