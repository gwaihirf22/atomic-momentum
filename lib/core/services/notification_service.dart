import '../../domain/entities/habit_notify.dart';
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

  /// On Android 12 and later, exact times need the user's say-so (off by
  /// default from Android 14): without it, notifications are scheduled
  /// inexactly (Android may hold them a few minutes) rather than failing.
  static AndroidScheduleMode _androidScheduleMode = AndroidScheduleMode.exactAllowWhileIdle;

  static Future<void> _checkExactAlarms() async {
    final android =
        _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;
    final exact = await android.canScheduleExactNotifications();
    _androidScheduleMode =
        exact == false ? AndroidScheduleMode.inexactAllowWhileIdle : AndroidScheduleMode.exactAllowWhileIdle;
  }

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
  static final InitializationSettings initializationSettings = InitializationSettings(
    android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: _darwinSettings,
    macOS: _darwinSettings,
  );

  static final DarwinInitializationSettings _darwinSettings = DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
    // Vacation check-ins carry an "I'm back" button; it opens the app, which
    // ends vacation mode
    notificationCategories: [
      DarwinNotificationCategory(vacationCategory, actions: [
        DarwinNotificationAction.plain(vacationBackAction, "I'm back",
            options: {DarwinNotificationActionOption.foreground}),
      ]),
    ],
  );

  static bool _timeZonesLoaded = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Initialize timezone data (configureLocalTimeZone loads it, once)
      await configureLocalTimeZone();

      // Initialize the plugin
      await _notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Permission is asked separately (see requestPermission), so startup
      // never waits on the system prompt
      _initialized = true;
      await _checkExactAlarms();

      // Opened by tapping a notification while the app wasn't running
      final launch = await _notificationsPlugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        handleResponse(launch!.notificationResponse?.actionId, launch.notificationResponse?.payload);
      }
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
      // The whole database is parsed: once is enough
      if (!_timeZonesLoaded) {
        tz.initializeTimeZones();
        _timeZonesLoaded = true;
      }
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

  static void _onNotificationTapped(NotificationResponse response) =>
      handleResponse(response.actionId, response.payload);

  /// A tapped notification, or one of its buttons ([actionId]).
  @visibleForTesting
  static void handleResponse(String? actionId, String? payload) {
    if (actionId == vacationBackAction) {
      vacationBackRequests.value++;
      return;
    }
    handleTap(payload);
  }

  /// Counts taps on a vacation check-in's "I'm back": the app ends vacation
  /// mode when it changes.
  static final vacationBackRequests = ValueNotifier<int>(0);

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
    if (payload == null || payload.isEmpty || payload == testPayload || payload == vacationPayload) return null;
    if (payload.startsWith(reminderPayloadPrefix)) {
      final id = payload.substring(reminderPayloadPrefix.length);
      return id.isEmpty ? null : id;
    }
    return payload;
  }

  /// Payload of the developer tester's notifications.
  static const testPayload = 'test';

  /// Payload of vacation mode's check-ins and welcome back.
  static const vacationPayload = 'vacation';

  /// The vacation check-ins' category (iOS) and their "I'm back" button.
  static const vacationCategory = 'vacation';
  static const vacationBackAction = 'vacation_back';

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
    NotificationDetails? details,
  }) async {
    if (!_initialized) return;
    try {
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        // An absolute instant, so it fires at the right moment whatever tz.local is
        tz.TZDateTime.from(at, tz.UTC),
        details ?? _getNotificationDetails(),
        payload: '$reminderPayloadPrefix$habitId',
        androidScheduleMode: _androidScheduleMode,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('NotificationService: Failed to schedule reminder for $habitId: $e');
    }
  }

  /// Cancels one pending notification.
  static Future<void> cancel(int id) async {
    if (!_initialized) return;
    try {
      await _notificationsPlugin.cancel(id);
    } catch (e) {
      debugPrint('NotificationService: Failed to cancel $id: $e');
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

  /// Schedules one of vacation mode's notifications (planned by
  /// VacationNoticePlanner); a check-in ([canEnd]) has an "I'm back" button.
  static Future<void> scheduleVacationNotice({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required bool canEnd,
  }) async {
    if (!_initialized) return;
    try {
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(at, tz.UTC),
        vacationDetails(canEnd: canEnd),
        payload: vacationPayload,
        androidScheduleMode: _androidScheduleMode,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('NotificationService: Failed to schedule a vacation notice: $e');
    }
  }

  /// Cancels every pending vacation notice.
  static Future<void> cancelVacationNotices() async {
    if (!_initialized) return;
    try {
      final pending = await _notificationsPlugin.pendingNotificationRequests();
      for (final request in pending) {
        if (request.payload == vacationPayload) await _notificationsPlugin.cancel(request.id);
      }
    } catch (e) {
      debugPrint('NotificationService: Failed to cancel vacation notices: $e');
    }
  }

  /// How vacation notices arrive: quietly important, on their own Android
  /// channel, with "I'm back" on check-ins.
  @visibleForTesting
  static NotificationDetails vacationDetails({required bool canEnd}) {
    final android = AndroidNotificationDetails(
      'vacation',
      'Vacation mode',
      channelDescription: 'Check-ins while vacation mode is on, and a welcome back',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
      actions: [
        if (canEnd)
          const AndroidNotificationAction(vacationBackAction, "I'm back",
              showsUserInterface: true, cancelNotification: true),
      ],
    );
    final darwin = DarwinNotificationDetails(
      categoryIdentifier: canEnd ? vacationCategory : null,
      threadIdentifier: 'vacation',
    );
    return NotificationDetails(android: android, iOS: darwin, macOS: darwin);
  }

  // Schedule a one-off warning that a habit's streak is at stake
  static Future<void> scheduleStreakWarning(String habitId, StreakWarning warning, {NotificationDetails? details}) async {
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
        details ?? _getNotificationDetails(),
        payload: habitId,
        androidScheduleMode: _androidScheduleMode,
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

  /// Cancels pending streak warnings for habits not in [habitIds]: habits
  /// that went without being deleted (a year of use loaded or put back).
  /// A streak warning's payload is its bare habit id; reminders
  /// (`reminder|…`) and the tester's notifications are left alone.
  static Future<void> cancelStreakWarningsExcept(Set<String> habitIds) async {
    if (!_initialized) return;
    try {
      final pending = await _notificationsPlugin.pendingNotificationRequests();
      for (final request in pending) {
        final payload = request.payload;
        if (payload == null || payload.isEmpty || payload == testPayload || payload == vacationPayload) continue;
        if (payload.startsWith(reminderPayloadPrefix)) continue;
        if (request.id == habitTapTestNotificationId || request.id == testNotificationId) continue;
        if (!habitIds.contains(payload)) await _notificationsPlugin.cancel(request.id);
      }
    } catch (e) {
      debugPrint('NotificationService: Failed to cancel warnings of habits that are gone: $e');
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
    NotificationDetails? details,
  }) async {
    if (!isSupported) return false;

    try {
      await _notificationsPlugin.show(id, title, body, details ?? _getNotificationDetails(), payload: payload);
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
        androidScheduleMode: _androidScheduleMode,
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
        androidScheduleMode: _androidScheduleMode,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
      return at;
    } catch (e) {
      debugPrint('NotificationService: Failed to schedule tap test: $e');
      return null;
    }
  }

  /// How a notification arrives: [sound] (a bundled tone, iOS's own, or
  /// silent) and whether it may break through Focus. Android keeps one
  /// channel per sound, since a channel's sound can't change once made.
  static NotificationDetails detailsFor({NotifySound sound = NotifySound.system, bool timeSensitive = false}) {
    final silent = sound == NotifySound.silent;
    final file = sound.fileName;
    final android = AndroidNotificationDetails(
      sound == NotifySound.system ? 'habit_reminders' : 'habit_reminders_${sound.name}',
      sound == NotifySound.system ? 'Habit Reminders' : 'Habit Reminders (${sound.label})',
      channelDescription: 'Reminders to complete your daily habits',
      importance: silent ? Importance.low : Importance.high,
      priority: silent ? Priority.low : Priority.high,
      playSound: !silent,
      sound: file == null ? null : RawResourceAndroidNotificationSound(sound.name),
      ticker: 'Habit Reminder',
      icon: '@mipmap/ic_launcher',
    );
    final darwin = DarwinNotificationDetails(
      categoryIdentifier: 'habit_reminder',
      threadIdentifier: 'habit_reminders',
      presentSound: !silent,
      sound: file,
      interruptionLevel: timeSensitive ? InterruptionLevel.timeSensitive : InterruptionLevel.active,
    );
    return NotificationDetails(android: android, iOS: darwin, macOS: darwin);
  }

  /// Plays how [sound] will arrive: a notification right away (shown even
  /// with the app open), so choosing a sound can be heard.
  static Future<bool> preview(NotifySound sound) => showNow(
        title: 'Momentum',
        body: sound == NotifySound.silent ? 'Habits will arrive silently.' : 'This is how habits will sound.',
        details: detailsFor(sound: sound),
      );

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
}

/// A request to show a habit on the Habits screen. A new object each time,
/// so tapping the same habit's notification twice still gets noticed.
class HabitFocusRequest {
  final String habitId;

  HabitFocusRequest(this.habitId);
}

/// Settings' notification defaults: the sound for habits without their own,
/// and whether time-sensitive habits may break through Focus.
class NotifyDefaults {
  final NotifySound sound;
  final bool allowTimeSensitive;

  const NotifyDefaults({this.sound = NotifySound.chime, this.allowTimeSensitive = true});

  static const standard = NotifyDefaults();

  /// What these defaults change about a notification, to tell whether
  /// what's scheduled still matches.
  String get key => '${sound.name}|$allowTimeSensitive';

  /// The sound [notify] plays here.
  NotifySound soundFor(HabitNotify notify) => notify.sound ?? sound;

  /// Whether [notify] arrives as time-sensitive.
  bool timeSensitiveFor(HabitNotify notify) => notify.timeSensitive && allowTimeSensitive;

  NotificationDetails detailsFor(HabitNotify notify) =>
      NotificationService.detailsFor(sound: soundFor(notify), timeSensitive: timeSensitiveFor(notify));
}
