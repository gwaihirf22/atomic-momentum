import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;

/// One notification request, as iOS holds it.
class SimRequest {
  final int id;
  final String? title;
  final String? body;
  final String? payload;

  /// When it fires, in local time.
  final DateTime at;

  const SimRequest({required this.id, required this.title, required this.body, required this.payload, required this.at});

  bool get isReminder => payload?.startsWith('reminder|') ?? false;

  /// The habit it's about: reminders carry `reminder|<id>`, streak warnings
  /// carry the bare id.
  String? get habitId => isReminder ? payload!.substring('reminder|'.length) : payload;
}

/// A stand-in for the iOS notification center, plugged in under the real
/// NotificationService. It holds pending requests the way iOS does (one per
/// id, a new one with the same id replaces it, at most 64: iOS keeps the
/// soonest-firing 64 and silently discards the rest) and delivers them when
/// simulated time reaches them.
class SimulatedNotificationCenter extends Fake implements FlutterLocalNotificationsPlugin {
  /// iOS's limit on pending local notifications.
  static const iosPendingLimit = 64;

  final Map<int, SimRequest> pending = {};

  /// Requests iOS would have discarded for going over [iosPendingLimit].
  final List<({SimRequest request, DateTime when})> dropped = [];

  /// Requests scheduled for a time already past: iOS never shows them.
  final List<SimRequest> scheduledInPast = [];

  /// The current simulated time, to spot requests scheduled in the past.
  DateTime Function() now = () => DateTime(2000);

  /// Every scheduling call, for debugging a failing scenario.
  int scheduleCalls = 0;

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
    scheduleCalls++;
    // The instant, in this process's local time
    final at = DateTime.fromMicrosecondsSinceEpoch(scheduledDate.microsecondsSinceEpoch);
    final request = SimRequest(id: id, title: title, body: body, payload: payload, at: at);
    if (!at.isAfter(now())) {
      scheduledInPast.add(request);
      return;
    }
    pending[id] = request;
    _applyLimit();
  }

  void _applyLimit() {
    if (pending.length <= iosPendingLimit) return;
    final byTime = pending.values.toList()..sort((a, b) => a.at.compareTo(b.at));
    for (final extra in byTime.skip(iosPendingLimit)) {
      pending.remove(extra.id);
      dropped.add((request: extra, when: now()));
    }
  }

  @override
  Future<void> cancel(int id, {String? tag}) async {
    pending.remove(id);
  }

  @override
  Future<void> cancelAll() async => pending.clear();

  @override
  Future<List<PendingNotificationRequest>> pendingNotificationRequests() async => [
        for (final r in pending.values) PendingNotificationRequest(r.id, r.title, r.body, r.payload),
      ];

  @override
  Future<void> show(int id, String? title, String? body, NotificationDetails? notificationDetails,
      {String? payload}) async {}

  @override
  T? resolvePlatformSpecificImplementation<T extends FlutterLocalNotificationsPlatform>() => null;

  /// Removes and returns every request due by [time], soonest first: what
  /// the phone shows as time passes.
  List<SimRequest> deliverDue(DateTime time) {
    final due = pending.values.where((r) => !r.at.isAfter(time)).toList()
      // Same minute: a fixed order, so timelines compare between runs
      ..sort((a, b) {
        final byTime = a.at.compareTo(b.at);
        return byTime != 0 ? byTime : '${a.title}${a.body}'.compareTo('${b.title}${b.body}');
      });
    for (final r in due) {
      pending.remove(r.id);
    }
    return due;
  }
}
