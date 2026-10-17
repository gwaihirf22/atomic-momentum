import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atomic_momentum/core/services/notification_service.dart';
import 'package:atomic_momentum/domain/entities/habit_notify.dart';
import 'package:atomic_momentum/domain/entities/quiet_hours.dart';
import 'package:atomic_momentum/presentation/providers/settings_provider.dart';

/// Sounds, time-sensitive alerts and quiet hours.
void main() {
  group('quiet hours', () {
    const quiet = QuietHours(enabled: true); // 22:00 to 07:00
    DateTime at(int day, int hour, [int minute = 0]) => DateTime(2026, 10, day, hour, minute);

    test('the window spans midnight', () {
      expect(quiet.contains(at(5, 22)), isTrue);
      expect(quiet.contains(at(5, 23, 30)), isTrue);
      expect(quiet.contains(at(6, 3)), isTrue);
      expect(quiet.contains(at(6, 7)), isFalse);
      expect(quiet.contains(at(5, 21, 59)), isFalse);
      expect(QuietHours.off.contains(at(6, 3)), isFalse);
    });

    test('late ones come a little before it, early ones when it ends, on the same day', () {
      expect(quiet.shift(at(5, 23)), at(5, 21, 45));
      expect(quiet.shift(at(5, 22, 30)), at(5, 21, 45));
      expect(quiet.shift(at(6, 6)), at(6, 7));
      expect(quiet.shift(at(6, 0, 30)), at(6, 7));
      expect(quiet.shift(at(5, 12)), at(5, 12), reason: 'outside the window');
    });

    test('a daytime window', () {
      const nap = QuietHours(enabled: true, start: TimeOfDay(hour: 13, minute: 0), end: TimeOfDay(hour: 15, minute: 0));
      expect(nap.contains(at(5, 14)), isTrue);
      expect(nap.contains(at(5, 16)), isFalse);
      expect(nap.shift(at(5, 14)), at(5, 15));
    });
  });

  group('notification details', () {
    DarwinNotificationDetails ios(NotificationDetails d) => d.iOS!;
    AndroidNotificationDetails android(NotificationDetails d) => d.android!;

    test('a Momentum tone plays its bundled file, on its own Android channel', () {
      final d = NotificationService.detailsFor(sound: NotifySound.chime);
      expect(ios(d).sound, 'chime.wav');
      expect(ios(d).presentSound, isTrue);
      expect(android(d).channelId, 'habit_reminders_chime');
      expect((android(d).sound as RawResourceAndroidNotificationSound).sound, 'chime');
    });

    test("iOS's own sound, and silence", () {
      final system = NotificationService.detailsFor();
      expect(ios(system).sound, isNull);
      expect(ios(system).presentSound, isTrue);
      expect(android(system).channelId, 'habit_reminders', reason: 'the channel earlier versions made');

      final silent = NotificationService.detailsFor(sound: NotifySound.silent);
      expect(ios(silent).presentSound, isFalse);
      expect(android(silent).playSound, isFalse);
    });

    test('time-sensitive breaks through Focus', () {
      expect(ios(NotificationService.detailsFor(timeSensitive: true)).interruptionLevel, InterruptionLevel.timeSensitive);
      expect(ios(NotificationService.detailsFor()).interruptionLevel, InterruptionLevel.active);
    });

    test("a habit uses Settings' sound unless it has its own; time-sensitive only where allowed", () {
      const defaults = NotifyDefaults(sound: NotifySound.soft);
      expect(defaults.soundFor(HabitNotify.standard), NotifySound.soft);
      expect(defaults.soundFor(const HabitNotify(sound: NotifySound.ding)), NotifySound.ding);
      expect(defaults.timeSensitiveFor(const HabitNotify(timeSensitive: true)), isTrue);
      expect(const NotifyDefaults(allowTimeSensitive: false).timeSensitiveFor(const HabitNotify(timeSensitive: true)),
          isFalse);
    });
  });

  group('settings', () {
    test('Chime, time-sensitive allowed, and quiet hours off to start; all saved', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider(await SharedPreferences.getInstance());
      expect(settings.notifySound, NotifySound.chime);
      expect(settings.allowTimeSensitive, isTrue);
      expect(settings.quietHours, QuietHours.off);

      await settings.setNotifySound(NotifySound.silent);
      await settings.setAllowTimeSensitive(false);
      await settings.setQuietHours(
          const QuietHours(enabled: true, start: TimeOfDay(hour: 23, minute: 30), end: TimeOfDay(hour: 6, minute: 0)));

      final reloaded = SettingsProvider(await SharedPreferences.getInstance());
      expect(reloaded.notifySound, NotifySound.silent);
      expect(reloaded.allowTimeSensitive, isFalse);
      expect(reloaded.quietHours,
          const QuietHours(enabled: true, start: TimeOfDay(hour: 23, minute: 30), end: TimeOfDay(hour: 6, minute: 0)));
      expect(reloaded.notifyDefaults.sound, NotifySound.silent);
    });
  });
}
