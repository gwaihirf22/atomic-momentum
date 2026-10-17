import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import '../core/services/notification_service.dart';
import '../domain/entities/habit.dart';
import '../domain/entities/category.dart';
import '../domain/entities/habit_color.dart';
import '../domain/entities/streak_warning_settings.dart';
import '../domain/services/streak_warning_planner.dart';
import '../presentation/providers/habit_provider.dart';
import 'package:clock/clock.dart';

/// Developer tool (debug builds only) for checking that notifications work on
/// this device: permission, immediate and scheduled delivery, the streak
/// warning text, and what is currently queued.
class NotificationTesterScreen extends StatefulWidget {
  const NotificationTesterScreen({Key? key}) : super(key: key);

  @override
  State<NotificationTesterScreen> createState() => _NotificationTesterScreenState();
}

class _NotificationTesterScreenState extends State<NotificationTesterScreen> {
  static const _scheduleDelay = Duration(seconds: 10);

  NotificationPermission? _permission;
  List<PendingNotificationRequest> _pending = const [];
  String? _status;

  bool get _supported => NotificationService.isSupported;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final permission = await NotificationService.permissionStatus();
    final pending = _supported
        ? await NotificationService.getPendingNotifications()
        : const <PendingNotificationRequest>[];
    if (!mounted) return;
    setState(() {
      _permission = permission;
      _pending = pending;
    });
  }

  void _report(String message) {
    if (mounted) setState(() => _status = message);
  }

  Future<void> _requestPermission() async {
    final granted = await NotificationService.requestPermission();
    _report(granted ? 'Permission granted.' : 'Permission not granted. Check System Settings → Notifications.');
    await _refresh();
  }

  Future<void> _sendNow() async {
    final sent = await NotificationService.showNow(
      title: 'Test notification',
      body: 'If you can see this, notifications are working.',
    );
    _report(sent ? 'Sent. It should appear now.' : 'Could not send the notification.');
  }

  Future<void> _sendLater() async {
    final at = await NotificationService.scheduleTestNotification(_scheduleDelay);
    if (at == null) {
      _report('Could not schedule the notification.');
    } else {
      _report('Scheduled for ${TimeOfDay.fromDateTime(at).format(context)}:'
          '${at.second.toString().padLeft(2, '0')}. Switch to another app to see it arrive.');
    }
    await _refresh();
  }

  Future<void> _previewStreakWarning() async {
    final now = clock.now();
    // Zero lead time: preview the message as of the deadline itself
    const settings = StreakWarningSettings(enabled: true, leadTime: Duration.zero);
    final habits = context.read<HabitProvider>().habits;

    // Prefer a real habit; otherwise use an example so the notification itself
    // can always be tested
    var isExample = false;
    StreakWarning? warning;
    String? habitName;
    for (final habit in habits.where((h) => h.streak.current > 0)) {
      warning = StreakWarningPlanner.plan(habit, settings, now).firstOrNull;
      if (warning != null) {
        habitName = habit.name;
        break;
      }
    }
    if (warning == null) {
      final example = _exampleHabitWithStreak(now);
      warning = StreakWarningPlanner.plan(example, settings, now).first;
      habitName = example.name;
      isExample = true;
    }

    final sent = await NotificationService.showNow(
      id: NotificationService.streakPreviewNotificationId,
      title: warning.title,
      body: warning.body,
    );
    if (!sent) {
      _report('Could not send the notification.');
    } else if (isExample) {
      _report('Sent an example streak warning (no habit has a streak yet; '
          'add sample habits in Settings to preview a real one).');
    } else {
      _report('Sent a streak warning for "$habitName".');
    }
  }

  // A daily habit completed yesterday and the day before: a 2-day streak
  Habit _exampleHabitWithStreak(DateTime now) {
    var habit = Habit.create(
      name: 'Example habit',
      target: 1,
      color: HabitColor.blue,
      categoryId: BuiltInCategoryIds.body,
    );
    for (final daysAgo in const [2, 1]) {
      habit = habit.setProgressForDate(DateTime(now.year, now.month, now.day - daysAgo), 1);
    }
    return habit.refresh(now);
  }

  String _permissionText(NotificationPermission? permission) {
    switch (permission) {
      case NotificationPermission.granted:
        return 'Allowed';
      case NotificationPermission.denied:
        return 'Not allowed';
      case NotificationPermission.unknown:
        return 'Unknown';
      case NotificationPermission.unsupported:
        return 'Not available here';
      case null:
        return 'Checking…';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification Tester')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            if (!_supported)
              Card(
                key: const Key('notificationsUnsupported'),
                margin: const EdgeInsets.all(16),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Notifications can\'t be shown in a web browser. Run the app on macOS, '
                    'iOS or Android to test them, e.g. ./flutter/bin/flutter run -d macos',
                  ),
                ),
              ),
            ListTile(
              leading: const Icon(Icons.verified_user_outlined),
              title: const Text('Permission'),
              subtitle: Text(_permissionText(_permission), key: const Key('permissionStatus')),
              trailing: _supported && _permission != NotificationPermission.granted
                  ? TextButton(onPressed: _requestPermission, child: const Text('Request'))
                  : null,
            ),
            const Divider(),
            _action(
              key: const Key('sendNow'),
              icon: Icons.notifications_active_outlined,
              title: 'Send now',
              subtitle: 'Shows a notification immediately',
              onTap: _sendNow,
            ),
            _action(
              key: const Key('sendLater'),
              icon: Icons.timer_outlined,
              title: 'Send in ${_scheduleDelay.inSeconds} seconds',
              subtitle: 'Tests scheduled delivery; switch away from the app after tapping',
              onTap: _sendLater,
            ),
            _action(
              key: const Key('previewStreakWarning'),
              icon: Icons.local_fire_department_outlined,
              title: 'Preview a streak warning',
              subtitle: 'Uses your first habit with a streak, or an example habit',
              onTap: _previewStreakWarning,
            ),
            if (_status != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(_status!, key: const Key('testerStatus'),
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
            const Divider(height: 32),
            ListTile(
              title: Text('Scheduled (${_pending.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Reminders, streak warnings and tests waiting to be delivered'),
              trailing: IconButton(
                key: const Key('refreshPending'),
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: _refresh,
              ),
            ),
            if (_pending.isEmpty)
              const ListTile(title: Text('Nothing scheduled')),
            for (final request in _pending)
              ListTile(
                dense: true,
                leading: const Icon(Icons.schedule),
                title: Text(request.title ?? '(no title)'),
                subtitle: Text(request.body ?? ''),
              ),
          ],
        ),
      ),
    );
  }

  Widget _action({
    required Key key,
    required IconData icon,
    required String title,
    required String subtitle,
    required Future<void> Function() onTap,
  }) {
    return ListTile(
      key: key,
      enabled: _supported,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: _supported ? onTap : null,
    );
  }
}
