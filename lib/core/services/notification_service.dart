import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../../domain/services/streak_warning_planner.dart';
import 'package:clock/clock.dart';

/// Whether the app may show notifications on this device.
enum NotificationPermission { granted, denied, unknown, unsupported }

class NotificationService {
  static FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// IDs used by the developer notification tester.
  static const int testNotificationId = 999;
  static const int scheduledTestNotificationId = 998;
  // Separate from testNotificationId: macOS quietly replaces a delivered
  // notification that reuses an id, without showing a new banner
  static const int streakPreviewNotificationId = 997;
  static const int habitTapTestNotificationId = 996;

  /// Substitutes the plugin (and readiness) in tests, where there is no
  /// platform implementation to talk to.
  @visibleForTesting
  static void debugOverride({required FlutterLocalNotificationsPlugin plugin, bool initialized = true}) {
    _notificationsPlugin = plugin;
    _initialized = initialized;
    _supportedOverride = initialized;
  }

  @visibleForTesting
  static void debugReset() {
    _notificationsPlugin = FlutterLocalNotificationsPlugin();
    _initialized = false;
    _supportedOverride = null;
  }

  static bool? _supportedOverride;

  /// The plugin silently does nothing on the web, so notifications can only
  /// be seen in the iOS, Android or macOS apps.
  static bool get isSupported => _supportedOverride ?? (!kIsWeb && _initialized);

  /// Looks up the device's IANA timezone (e.g. "America/Los_Angeles").
  /// Replaceable in tests, where the platform plugin isn't available.
  @visibleForTesting
  static Future<String> Function() timezoneResolver =
      () async => (await FlutterTimezone.getLocalTimezone()).identifier;

  /// Plugin setup. Doesn't ask for permission: on iOS and macOS the prompt
  /// would block startup until answered, over a blank screen.
  @visibleForTesting
  static const InitializationSettings initializationSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: _darwinSettings,
    macOS: _darwinSettings,
  );

  static const DarwinInitializationSettings _darwinSettings = DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );

  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Initialize timezone data
      tz.initializeTimeZones();
      await configureLocalTimeZone();

      // Initialize the plugin
      await _notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Permission is asked separately (see requestPermission), so startup
      // never waits on the system prompt
      _initialized = true;

      // Opened by tapping a notification while the app wasn't running
      final launch = await _notificationsPlugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) handleTap(launch!.notificationResponse?.payload);
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

  /// Asks the OS for permission to show notifications. Returns whether it
  /// was granted (false if declined or unavailable).
  static Future<bool> requestPermission() async {
    try {
      final ios = _notificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        return await ios.requestPermissions(alert: true, badge: true, sound: true) ?? false;
      }
      final macos = _notificationsPlugin
          .resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>();
      if (macos != null) {
        return await macos.requestPermissions(alert: true, badge: true, sound: true) ?? false;
      }
      final android = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      return false;
    } catch (e) {
      debugPrint('NotificationService: Failed to request permissions: $e');
      return false;
    }
  }

  /// Current permission without prompting the user.
  static Future<NotificationPermission> permissionStatus() async {
    if (!isSupported) return NotificationPermission.unsupported;

    try {
      bool? enabled;
      final ios = _notificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      final macos = _notificationsPlugin
          .resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>();
      final android = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        enabled = (await ios.checkPermissions())?.isEnabled;
      } else if (macos != null) {
        enabled = (await macos.checkPermissions())?.isEnabled;
      } else if (android != null) {
        enabled = await android.areNotificationsEnabled();
      }

      if (enabled == null) return NotificationPermission.unknown;
      return enabled ? NotificationPermission.granted : NotificationPermission.denied;
    } catch (e) {
      debugPrint('NotificationService: Failed to check permissions: $e');
      return NotificationPermission.unknown;
    }
  }

  static void _onNotificationTapped(NotificationResponse response) => handleTap(response.payload);

  /// A habit to show because its notification was tapped. The tab bar
  /// switches to Habits and the Habits screen scrolls to the card and
  /// highlights it, then clears this.
  static final focusRequests = ValueNotifier<HabitFocusRequest?>(null);

  /// Turns a tapped notification's payload into a focus request.
  @visibleForTesting
  static void handleTap(String? payload) {
    final habitId = habitIdFromPayload(payload);
    if (habitId != null) focusRequests.value = HabitFocusRequest(habitId);
  }

  /// The habit a notification is about: reminders carry
  /// `reminder|<habitId>`, streak warnings the bare id; test notifications
  /// none.
  static String? habitIdFromPayload(String? payload) {
    if (payload == null || payload.isEmpty || payload == testPayload) return null;
    if (payload.startsWith(reminderPayloadPrefix)) {
      final id = payload.substring(reminderPayloadPrefix.length);
      return id.isEmpty ? null : id;
    }
    return payload;
  }

  /// Payload of the developer tester's notifications.
  static const testPayload = 'test';

  /// Payloads of habit reminders start with this, so they can be found and
  /// replaced as a set (see ReminderService).
  static const reminderPayloadPrefix = 'reminder|';

  /// Schedules one habit reminder for an absolute instant (planned by
  /// ReminderPlanner; one-off, not repeating, so finished days can be skipped).
  static Future<void> scheduleReminder({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required String habitId,
  }) async {
    if (!_initialized) return;
    try {
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        // An absolute instant, so it fires at the right moment whatever tz.local is
        tz.TZDateTime.from(at, tz.UTC),
        _getNotificationDetails(),
        payload: '$reminderPayloadPrefix$habitId',
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('NotificationService: Failed to schedule reminder for $habitId: $e');
    }
  }

  /// Cancels every pending habit reminder.
  static Future<void> cancelPendingReminders() async {
    if (!_initialized) return;
    try {
      final pending = await _notificationsPlugin.pendingNotificationRequests();
      for (final request in pending) {
        if (request.payload?.startsWith(reminderPayloadPrefix) ?? false) {
          await _notificationsPlugin.cancel(request.id);
        }
      }
    } catch (e) {
      debugPrint('NotificationService: Failed to cancel reminders: $e');
    }
  }

  /// Cancels the weekly repeating reminders earlier versions scheduled.
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

  // Schedule a one-off warning that a habit's streak is at stake
  static Future<void> scheduleStreakWarning(String habitId, StreakWarning warning) async {
    if (!_initialized) return;

    try {
      final id = _getStreakWarningId(habitId, warning.kind);
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
      for (final kind in StreakWarningKind.values) {
        await _notificationsPlugin.cancel(_getStreakWarningId(habitId, kind));
      }
    } catch (e) {
      debugPrint('NotificationService: Failed to cancel streak warning for $habitId: $e');
    }
  }

  static int _getStreakWarningId(String habitId, StreakWarningKind kind) {
    // The second-miss warning keeps the original id, so warnings scheduled by
    // earlier versions are replaced rather than duplicated
    final suffix = kind == StreakWarningKind.secondMiss ? 'streak-warning' : 'streak-${kind.name}';
    return '$habitId-$suffix'.hashCode.abs() % 2147483647;
  }

  /// Shows a notification immediately. Returns false if it couldn't be sent.
  static Future<bool> showNow({
    required String title,
    required String body,
    int id = testNotificationId,
    String payload = testPayload,
  }) async {
    if (!isSupported) return false;

    try {
      await _notificationsPlugin.show(id, title, body, _getNotificationDetails(), payload: payload);
      return true;
    } catch (e) {
      debugPrint('NotificationService: Failed to show notification: $e');
      return false;
    }
  }

  /// Schedules a one-off notification [delay] from now, to check scheduled
  /// delivery (e.g. with the app in the background). Returns when it will
  /// fire, or null if it couldn't be scheduled.
  static Future<DateTime?> scheduleTestNotification(Duration delay) async {
    if (!isSupported) return null;

    try {
      final at = clock.now().add(delay);
      await _notificationsPlugin.zonedSchedule(
        scheduledTestNotificationId,
        'Scheduled test',
        'Scheduled ${delay.inSeconds} seconds ago from the notification tester.',
        tz.TZDateTime.from(at, tz.UTC),
        _getNotificationDetails(),
        payload: testPayload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      return at;
    } catch (e) {
      debugPrint('NotificationService: Failed to schedule test notification: $e');
      return null;
    }
  }

  /// Schedules a notification about [habitId] [delay] from now, for trying
  /// out what tapping one does (it opens Habits at that habit). It carries
  /// the bare habit id, as streak warnings do, so reminder resyncs in the
  /// meantime don't cancel it. Returns when it fires, or null on failure.
  static Future<DateTime?> scheduleHabitTapTest({
    required String habitId,
    required String habitName,
    required Duration delay,
  }) async {
    if (!isSupported) return null;

    try {
      final at = clock.now().add(delay);
      await _notificationsPlugin.zonedSchedule(
        habitTapTestNotificationId,
        'Tap to open $habitName',
        'From the notification tester: should open Habits at "$habitName".',
        tz.TZDateTime.from(at, tz.UTC),
        _getNotificationDetails(),
        payload: habitId,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
      return at;
    } catch (e) {
      debugPrint('NotificationService: Failed to schedule tap test: $e');
      return null;
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

/// A request to show a habit on the Habits screen. A new object each time,
/// so tapping the same habit's notification twice still gets noticed.
class HabitFocusRequest {
  final String habitId;

  HabitFocusRequest(this.habitId);
}
