import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../../domain/entities/habit.dart';
import '../../domain/services/streak_warning_planner.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// Looks up the device's IANA timezone (e.g. "America/Los_Angeles").
  /// Replaceable in tests, where the platform plugin isn't available.
  @visibleForTesting
  static Future<String> Function() timezoneResolver =
      () async => (await FlutterTimezone.getLocalTimezone()).identifier;

  // Initialize the notification service
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Initialize timezone data
      tz.initializeTimeZones();
      await configureLocalTimeZone();

      // Android initialization settings
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS initialization settings
      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      // Combined initialization settings
      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
        macOS: iosSettings,
      );

      // Initialize the plugin
      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Request permissions for iOS/macOS
      if (!kIsWeb) {
        await _requestPermissions();
      }

      _initialized = true;
      debugPrint('NotificationService: Initialized successfully');
    } catch (e) {
      debugPrint('NotificationService: Failed to initialize: $e');
    }
  }

  /// Points tz.local at the device timezone. Without this tz.local stays UTC
  /// and repeating reminders fire at the UTC wall-clock time (e.g. a 9am
  /// reminder at 2am in California).
  static Future<void> configureLocalTimeZone() async {
    try {
      tz.initializeTimeZones();
      final identifier = await timezoneResolver();
      tz.setLocalLocation(tz.getLocation(identifier));
      debugPrint('NotificationService: Local timezone is $identifier');
    } catch (e) {
      debugPrint('NotificationService: Could not determine timezone, using UTC: $e');
    }
  }

  // Request notification permissions
  static Future<bool> _requestPermissions() async {
    try {
      final result = await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );

      return result ?? false;
    } catch (e) {
      debugPrint('NotificationService: Failed to request permissions: $e');
      return false;
    }
  }

  // Handle notification tap
  static void _onNotificationTapped(NotificationResponse response) {
    debugPrint('NotificationService: Notification tapped: ${response.payload}');
    // TODO: Handle navigation to habit details or home screen
  }

  // Schedule a single habit reminder
  static Future<bool> scheduleHabitReminder(Habit habit) async {
    if (!_initialized) {
      debugPrint('NotificationService: Not initialized, cannot schedule reminder');
      return false;
    }

    if (habit.reminder == null || !habit.reminder!.enabled) {
      debugPrint('NotificationService: No reminder set for habit ${habit.name}');
      return false;
    }

    try {
      await cancelHabitReminder(habit.id); // Cancel existing first

      final reminder = habit.reminder!;
      final message = reminder.customMessage ??
          _getDefaultReminderMessage(habit.name, habit.target, habit.units);

      // Schedule for each selected day of the week
      for (int dayOfWeek in reminder.daysOfWeek) {
        final notificationId = _getNotificationId(habit.id, dayOfWeek);
        
        final scheduledDate = nextOccurrence(
          dayOfWeek: dayOfWeek,
          timeOfDay: reminder.time,
          now: tz.TZDateTime.now(tz.local),
        );

        await _notificationsPlugin.zonedSchedule(
          notificationId,
          'Habit Reminder: ${habit.name}',
          message,
          scheduledDate,
          _getNotificationDetails(),
          payload: habit.id,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );

        debugPrint('NotificationService: Scheduled reminder for ${habit.name} on day $dayOfWeek at ${reminder.timeString}');
      }

      return true;
    } catch (e) {
      debugPrint('NotificationService: Failed to schedule reminder for ${habit.name}: $e');
      return false;
    }
  }

  // Cancel habit reminders
  static Future<void> cancelHabitReminder(String habitId) async {
    if (!_initialized) return;

    try {
      // Cancel all possible day combinations for this habit
      for (int dayOfWeek = 1; dayOfWeek <= 7; dayOfWeek++) {
        final notificationId = _getNotificationId(habitId, dayOfWeek);
        await _notificationsPlugin.cancel(notificationId);
      }

      debugPrint('NotificationService: Cancelled reminders for habit $habitId');
    } catch (e) {
      debugPrint('NotificationService: Failed to cancel reminders for $habitId: $e');
    }
  }

  // Schedule the one-off warning that a habit's streak is about to expire
  static Future<void> scheduleStreakWarning(String habitId, StreakWarning warning) async {
    if (!_initialized) return;

    try {
      final id = _getStreakWarningId(habitId);
      await _notificationsPlugin.cancel(id);
      await _notificationsPlugin.zonedSchedule(
        id,
        warning.title,
        warning.body,
        // An absolute instant, so it fires at the right moment whatever tz.local is
        tz.TZDateTime.from(warning.at, tz.UTC),
        _getNotificationDetails(),
        payload: habitId,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint('NotificationService: Scheduled streak warning for $habitId at ${warning.at}');
    } catch (e) {
      debugPrint('NotificationService: Failed to schedule streak warning for $habitId: $e');
    }
  }

  static Future<void> cancelStreakWarning(String habitId) async {
    if (!_initialized) return;

    try {
      await _notificationsPlugin.cancel(_getStreakWarningId(habitId));
    } catch (e) {
      debugPrint('NotificationService: Failed to cancel streak warning for $habitId: $e');
    }
  }

  static int _getStreakWarningId(String habitId) {
    return '$habitId-streak-warning'.hashCode.abs() % 2147483647;
  }

  // Update habit reminders (cancel old, schedule new)
  static Future<bool> updateHabitReminder(Habit habit) async {
    await cancelHabitReminder(habit.id);
    return await scheduleHabitReminder(habit);
  }

  // Show immediate notification (for testing)
  static Future<void> showTestNotification() async {
    if (!_initialized) {
      await initialize();
    }

    try {
      await _notificationsPlugin.show(
        999, // Test notification ID
        'Test Notification',
        'This is a test notification from Atomic Momentum!',
        _getNotificationDetails(),
        payload: 'test',
      );
      debugPrint('NotificationService: Test notification shown');
    } catch (e) {
      debugPrint('NotificationService: Failed to show test notification: $e');
    }
  }

  // Get notification details (styling)
  static NotificationDetails _getNotificationDetails() {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'habit_reminders',
      'Habit Reminders',
      channelDescription: 'Reminders to complete your daily habits',
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'Habit Reminder',
      icon: '@mipmap/ic_launcher',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      categoryIdentifier: 'habit_reminder',
      threadIdentifier: 'habit_reminders',
    );

    return const NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );
  }

  // Generate unique notification ID for habit + day combination
  static int _getNotificationId(String habitId, int dayOfWeek) {
    // Use hash of habit ID + day to create unique but consistent ID
    final combined = '$habitId-$dayOfWeek';
    return combined.hashCode.abs() % 2147483647; // Keep within int32 range
  }

  /// Next [dayOfWeek] at [timeOfDay] after [now], in [now]'s timezone.
  @visibleForTesting
  static tz.TZDateTime nextOccurrence({
    required int dayOfWeek,
    required TimeOfDay timeOfDay,
    required tz.TZDateTime now,
  }) {
    final daysUntilTarget = (dayOfWeek - now.weekday) % 7;
    final todayAtTime = tz.TZDateTime(
        now.location, now.year, now.month, now.day, timeOfDay.hour, timeOfDay.minute);
    // If it's today but the time has passed, use next week
    final daysAhead = daysUntilTarget == 0 && todayAtTime.isBefore(now) ? 7 : daysUntilTarget;

    // Build from calendar fields rather than adding 24h blocks, which would
    // shift the wall-clock time across a daylight-saving change
    final scheduledDate = tz.TZDateTime(now.location, now.year, now.month,
        now.day + daysAhead, timeOfDay.hour, timeOfDay.minute);

    return scheduledDate;
  }

  // Generate default reminder message
  static String _getDefaultReminderMessage(String habitName, int target, String units) {
    final targetText = units.isEmpty ? '$target' : '$target $units';
    return 'Time to work on your "$habitName" habit! Goal: $targetText';
  }

  // Get all pending notifications (for debugging)
  static Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    if (!_initialized) return [];
    
    try {
      return await _notificationsPlugin.pendingNotificationRequests();
    } catch (e) {
      debugPrint('NotificationService: Failed to get pending notifications: $e');
      return [];
    }
  }

  // Cancel all notifications
  static Future<void> cancelAllNotifications() async {
    if (!_initialized) return;

    try {
      await _notificationsPlugin.cancelAll();
      debugPrint('NotificationService: Cancelled all notifications');
    } catch (e) {
      debugPrint('NotificationService: Failed to cancel all notifications: $e');
    }
  }
}