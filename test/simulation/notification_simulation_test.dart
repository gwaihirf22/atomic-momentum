import 'dart:io';

import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/core/services/notification_service.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/entities/habit_goal.dart';
import 'package:atomic_momentum/domain/entities/quiet_hours.dart';
import 'package:atomic_momentum/domain/entities/reminder_settings.dart';
import 'package:atomic_momentum/domain/entities/reset_frequency.dart';
import 'package:atomic_momentum/domain/entities/two_minute_version.dart';
import 'package:atomic_momentum/domain/usecases/create_habit_usecase.dart';
import 'package:atomic_momentum/domain/usecases/update_habit_usecase.dart';

import 'simulated_phone.dart';

/// Six simulated weeks of the real app, checking every notification it
/// would show. Mon Sep 28 to Sun Nov 8 2026 spans three clock changes:
/// Lord Howe +30 min (Oct 4), Europe (Oct 25) and the US (Nov 1); run
/// tool/notification_sim.sh to try each zone.
///
/// Each scenario's timeline is compared with test/simulation/goldens/.
/// After an intended change, review the diff and update them with
/// `./flutter/bin/flutter test test/simulation --update-goldens`.
void main() {
  final start = DateTime(2026, 9, 28, 7, 0); // a Monday
  final end = DateTime(2026, 11, 9);
  const nine = TimeOfDay(hour: 9, minute: 0);

  tearDown(() async {
    NotificationService.debugReset();
    await resetDependencies();
  });

  Iterable<DateTime> days() sync* {
    for (var d = DateTime(start.year, start.month, start.day); d.isBefore(end); d = DateTime(d.year, d.month, d.day + 1)) {
      yield d;
    }
  }

  DateTime on(DateTime day, int hour, [int minute = 0]) => DateTime(day.year, day.month, day.day, hour, minute);

  CreateHabitParams habit(
    String name, {
    ResetFrequency frequency = ResetFrequency.daily,
    int interval = 1,
    List<int>? weekdays,
    DateTime? anchor,
    int target = 1,
    String units = '',
    ReminderSettings? reminder,
  }) =>
      CreateHabitParams(
        name: name,
        target: target,
        units: units,
        color: HabitColor.blue,
        categoryId: BuiltInCategoryIds.body,
        resetFrequency: frequency,
        resetInterval: interval,
        scheduledWeekdays: weekdays,
        resetAnchor: anchor ?? start,
        reminder: reminder ?? ReminderSettings.smart(time: nine),
      );

  /// One of every schedule the app offers, all on smart reminders at 9:00.
  final everySchedule = [
    habit('Daily'),
    habit('Mon Wed Fri', weekdays: [1, 3, 5]),
    habit('Every 2 days', interval: 2),
    habit('Every 3 days', interval: 3),
    habit('Weekly', frequency: ResetFrequency.weekly, target: 3, units: 'runs'),
    habit('Every 2 weeks', frequency: ResetFrequency.weekly, interval: 2),
    habit('Every 3 weeks', frequency: ResetFrequency.weekly, interval: 3),
    habit('Monthly 15th', frequency: ResetFrequency.monthly, anchor: DateTime(2026, 9, 15)),
    habit('Monthly 31st', frequency: ResetFrequency.monthly, anchor: DateTime(2026, 8, 31)),
    habit('Lifetime', frequency: ResetFrequency.never, target: 20, units: 'pages'),
  ];

  /// The usual day: a look at 07:30 and at 21:00.
  Future<void> usualDay(SimulatedPhone phone, DateTime day) async {
    await phone.checkIn(on(day, 7, 30));
    await phone.checkIn(on(day, 21));
  }

  void expectClean(SimulatedPhone phone, String golden) {
    expect(phone.failures, isEmpty, reason: '\n${phone.failures.join('\n')}');
    _expectGolden(phone.timeline, golden);
  }

  /// Completes whatever is still open for today among [names] (all habits
  /// by default) at [time]: daily ones are finished, weekly and monthly ones
  /// only on [when] days, lifetime habits get one more.
  Future<void> doHabits(
    SimulatedPhone phone,
    DateTime time, {
    List<String>? names,
    bool Function(Habit habit, DateTime day)? when,
  }) async {
    final day = DateTime(time.year, time.month, time.day);
    await phone.advanceTo(time);
    final todo = <String>[];
    for (final h in phone.habits.habits) {
      if (names != null && !names.contains(h.name)) continue;
      if (!h.schedule.isPeriodic) {
        if (h.progressForPeriodContaining(day) < h.target) todo.add(h.name);
        continue;
      }
      if (!h.isDueOn(day) || h.wasKeptOnDate(day)) continue;
      if (when != null && !when(h, day)) continue;
      todo.add(h.name);
    }
    if (todo.isEmpty) return;
    await phone.at(time, 'done       ${todo.join(', ')}', () async {
      for (final name in todo) {
        final h = phone.habit(name);
        await phone.log(name, h.schedule.isPeriodic ? h.target : h.progressForPeriodContaining(day) + 1);
      }
    });
  }

  /// The last day of the habit's period: when it's due.
  bool lastDay(Habit h, DateTime day) =>
      h.schedule.nextPeriodStart(day) == DateTime(day.year, day.month, day.day + 1);

  Future<void> createAll(SimulatedPhone phone, List<CreateHabitParams> params) =>
      phone.at(start, 'created    ${params.map((p) => p.name).join(', ')}', () async {
        for (final p in params) {
          await phone.create(p);
        }
      });

  test('1. every schedule, never done: each smart reminder day, once', () async {
    final phone = await SimulatedPhone.run(start, (phone) async {
      await createAll(phone, everySchedule);
      for (final day in days()) {
        await usualDay(phone, day);
      }
      await phone.advanceTo(end);
    });
    expectClean(phone, 'every_schedule_ignored');
  });

  test('2. every schedule, done at 08:00: no reminders, no warnings', () async {
    final phone = await SimulatedPhone.run(start, (phone) async {
      await createAll(phone, everySchedule);
      for (final day in days()) {
        await phone.checkIn(on(day, 7, 30));
        await doHabits(phone, on(day, 8));
        await phone.checkIn(on(day, 21));
      }
      await phone.advanceTo(end);
    });
    expectClean(phone, 'every_schedule_done_early');
    final reminders = phone.delivered.where((r) => r.isReminder && !r.title!.startsWith('Lifetime'));
    expect(reminders, isEmpty, reason: 'everything was done before 9:00');
    expect(phone.delivered.where((r) => !r.isReminder), isEmpty, reason: 'no streak was ever at stake');
  });

  test('3. every schedule, done at noon on the due day: countdowns, then silence', () async {
    final phone = await SimulatedPhone.run(start, (phone) async {
      await createAll(phone, everySchedule);
      for (final day in days()) {
        await phone.checkIn(on(day, 7, 30));
        await doHabits(phone, on(day, 12), when: lastDay);
        await phone.checkIn(on(day, 21));
      }
      await phone.advanceTo(end);
    });
    expectClean(phone, 'every_schedule_done_last_minute');
  });

  test("4. never miss twice: warnings after one miss, silence after two, lead times", () async {
    final misses = {
      DateTime(2026, 10, 2),
      DateTime(2026, 10, 9), DateTime(2026, 10, 10), // two in a row: the streak ends
      DateTime(2026, 10, 20),
      DateTime(2026, 10, 27),
      DateTime(2026, 11, 3), DateTime(2026, 11, 4),
    };
    final phone = await SimulatedPhone.run(start, (phone) async {
      await createAll(phone, [habit('Read')]);
      for (final day in days()) {
        await phone.checkIn(on(day, 7, 30));
        if (day == DateTime(2026, 10, 14)) {
          await phone.at(on(day, 7, 45), 'settings   warn 1 hour before', () => phone.warnings(lead: const Duration(hours: 1)));
        }
        if (day == DateTime(2026, 10, 21)) {
          await phone.at(on(day, 7, 45), 'settings   warn 24 hours before', () => phone.warnings(lead: const Duration(hours: 24)));
        }
        if (day == DateTime(2026, 10, 28)) {
          await phone.at(on(day, 7, 45), 'settings   warn 4 hours before, early nudge on',
              () => phone.warnings(lead: const Duration(hours: 4), firstMiss: true));
        }
        if (!misses.contains(day)) await doHabits(phone, on(day, 12));
        await phone.checkIn(on(day, 21, 30));
      }
      await phone.advanceTo(end);
    });
    expectClean(phone, 'never_miss_twice');
  });

  test('5. two-minute version: keeps the day, quiets reminders and warnings', () async {
    final phone = await SimulatedPhone.run(start, (phone) async {
      await createAll(phone, [
        habit('Run').withTwoMinute(const TwoMinuteVersion(description: 'Put on running shoes')),
        habit('Water', target: 8, units: 'glasses')
            .withTwoMinute(const TwoMinuteVersion(description: 'One glass', minimum: 1)),
      ]);
      for (final day in days()) {
        await phone.checkIn(on(day, 7, 30));
        final d = day.day + (day.month == 10 ? 0 : 100);
        // Run: 2 min before its reminder on the 5th, a miss on the 12th
        // rescued by 2 min at 19:00 on the 13th, 2 min then undone on the 20th
        if (d == 5 || d == 20) await phone.at(on(day, 8), '2 min      Run', () => phone.twoMinute('Run', true));
        // Water: one glass most mornings (the minimum), all 8 on Sundays
        if (day.weekday == DateTime.sunday) {
          await doHabits(phone, on(day, 8, 15), names: ['Water']);
        } else {
          await phone.at(on(day, 8, 15), 'logged     Water 1/8', () => phone.log('Water', 1));
        }
        if (d == 20) await phone.at(on(day, 10), 'undo 2 min Run', () => phone.twoMinute('Run', false));
        if (d == 13) await phone.at(on(day, 19), '2 min      Run', () => phone.twoMinute('Run', true));
        if (!{5, 12, 13, 20}.contains(d)) await doHabits(phone, on(day, 12), names: ['Run']);
        await phone.checkIn(on(day, 21));
      }
      await phone.advanceTo(end);
    });
    expectClean(phone, 'two_minute_version');
  });

  test('6. custom days, messages and edits: changes take effect at once', () async {
    final phone = await SimulatedPhone.run(start, (phone) async {
      await createAll(phone, [
        habit('Stretch', reminder: const ReminderSettings(
          time: TimeOfDay(hour: 7, minute: 0),
          enabled: true,
          daysOfWeek: [2, 4],
          customMessage: 'Roll out the mat',
        )),
        habit('Walk'),
        habit('Journal', reminder: ReminderSettings.smart(time: const TimeOfDay(hour: 21, minute: 30))),
        habit('Meditate'),
      ]);
      for (final day in days()) {
        await phone.checkIn(on(day, 6, 30));
        final d = day.day + (day.month == 10 ? 0 : 100);
        if (d == 7) {
          await phone.at(on(day, 8), 'edit       Walk: remind at 18:30',
              () => phone.edit('Walk', UpdateHabitParams(reminder: ReminderSettings.smart(time: const TimeOfDay(hour: 18, minute: 30)))));
        }
        if (d == 10) {
          await phone.at(on(day, 8), 'edit       Journal: reminder off',
              () => phone.edit('Journal', UpdateHabitParams(reminder: ReminderSettings.smart(time: const TimeOfDay(hour: 21, minute: 30)).copyWith(enabled: false))));
        }
        if (d == 14) {
          await phone.at(on(day, 8), 'edit       Walk: weekly, 3 walks',
              () => phone.edit('Walk', UpdateHabitParams(resetFrequency: ResetFrequency.weekly, target: 3, resetAnchor: start)));
        }
        if (d == 15) {
          await phone.at(on(day, 8), 'edit       Stretch: Mon Wed Fri',
              () => phone.edit('Stretch', const UpdateHabitParams(reminder: ReminderSettings(
                    time: TimeOfDay(hour: 7, minute: 0),
                    enabled: true,
                    daysOfWeek: [1, 3, 5],
                    customMessage: 'Roll out the mat',
                  ))));
        }
        if (d == 17) await phone.at(on(day, 8), 'settings   streak warnings off', () => phone.warnings(enabled: false));
        if (d == 21) await phone.at(on(day, 8), 'delete     Meditate', () => phone.delete('Meditate'));
        if (d == 24) await phone.at(on(day, 8), 'settings   streak warnings on', () => phone.warnings(enabled: true));

        // Walk: one walk most evenings; Journal: nightly, with a few misses
        if (!{18, 25}.contains(d)) await doHabits(phone, on(day, 19), names: ['Walk'], when: (h, _) => true);
        if (!{3, 11, 18, 25, 26}.contains(d)) await doHabits(phone, on(day, 22), names: ['Journal']);
      }
      await phone.advanceTo(end);
    });
    expectClean(phone, 'custom_and_edits');
  });

  test("7. vacation: what's scheduled still arrives; all resyncs on return", () async {
    final away = {for (var d = 10; d <= 15; d++) DateTime(2026, 10, d)};
    final phone = await SimulatedPhone.run(start, (phone) async {
      await createAll(phone, [
        habit('Read'),
        habit('Gym', weekdays: [1, 3, 5]),
        habit('Review', frequency: ResetFrequency.weekly),
      ]);
      for (final day in days()) {
        if (away.contains(day)) continue;
        // Back from vacation: the app was killed meanwhile
        if (day == DateTime(2026, 10, 16)) {
          await phone.advanceTo(on(day, 7, 30));
          await phone.at(on(day, 7, 30), 'launch     (after a week away)', () => phone.open(cold: true));
        } else {
          await phone.checkIn(on(day, 7, 30));
        }
        await doHabits(phone, on(day, 12), when: (h, d) => h.resetFrequency == ResetFrequency.daily || lastDay(h, d));
        await phone.checkIn(on(day, 21));
      }
      await phone.advanceTo(end);
    });
    expectClean(phone, 'vacation');
  });

  test("8. many habits: reminders and warnings fit in iOS's 64", () async {
    final phone = await SimulatedPhone.run(start, (phone) async {
      await createAll(phone, [for (var i = 1; i <= 12; i++) habit('Habit $i')]);
      await phone.at(start, 'settings   early nudge on', () => phone.warnings(firstMiss: true));
      for (final day in days()) {
        await phone.checkIn(on(day, 7, 30));
        // Habit 12 is skipped on Saturdays, so warnings fire too
        await doHabits(phone, on(day, 12),
            names: [for (var i = 1; i <= (day.weekday == DateTime.saturday ? 11 : 12); i++) 'Habit $i']);
        await phone.checkIn(on(day, 21));
      }
      await phone.advanceTo(end);
    });
    expectClean(phone, 'many_habits');
  });

  test('9. the app left open over midnight sends the same as one opened each day', () async {
    Future<SimulatedPhone> run({required bool leftOpen}) => SimulatedPhone.run(start, (phone) async {
          await createAll(phone, [habit('Read'), habit('Weekly', frequency: ResetFrequency.weekly, target: 2)]);
          if (leftOpen) await phone.keepOpen(start);
          for (final day in days()) {
            if (!leftOpen) await phone.checkIn(on(day, 7, 30));
            if (day.weekday != DateTime.tuesday && day.day % 5 != 0) {
              await doHabits(phone, on(day, 12), names: ['Read']);
            }
            if (day.weekday == DateTime.saturday) await doHabits(phone, on(day, 13), names: ['Weekly']);
          }
          await phone.advanceTo(end);
        });

    final open = await run(leftOpen: true);
    final visits = await run(leftOpen: false);
    expect(open.failures, isEmpty, reason: '\n${open.failures.join('\n')}');
    expect(visits.failures, isEmpty, reason: '\n${visits.failures.join('\n')}');
    expect(open.timeline, visits.timeline);
    _expectGolden(open.timeline, 'left_open_over_midnight');
  });

  test('11. habits being broken: a check-in every evening, never a streak warning', () async {
    final checkIn = ReminderSettings(
      time: const TimeOfDay(hour: 21, minute: 0),
      enabled: true,
      daysOfWeek: const [1, 2, 3, 4, 5, 6, 7],
    );
    final phone = await SimulatedPhone.run(start, (phone) async {
      await phone.at(start, 'created    Smoking (quit), Drinks (at most 2), Daily', () async {
        await phone.create(CreateHabitParams(
          name: 'Smoking',
          target: 0,
          color: HabitColor.red,
          categoryId: BuiltInCategoryIds.body,
          goal: HabitGoal.quit,
          resetAnchor: start,
          reminder: checkIn,
        ));
        await phone.create(CreateHabitParams(
          name: 'Drinks',
          target: 2,
          units: 'drinks',
          color: HabitColor.purple,
          categoryId: BuiltInCategoryIds.social,
          goal: HabitGoal.limit,
          resetAnchor: start,
          reminder: checkIn.copyWith(customMessage: 'How many drinks today?'),
        ));
        // A habit being built alongside, so warnings still flow for it
        await phone.create(habit('Daily'));
      });
      var d = 0;
      for (final day in days()) {
        d++;
        await phone.checkIn(on(day, 7, 30));
        if (d % 3 != 0) await doHabits(phone, on(day, 8), names: ['Daily']);
        // A few slips, two of them on days in a row
        if (d == 4 || d == 11 || d == 12) {
          await phone.at(on(day, 13), 'slipped    Smoking', () => phone.log('Smoking', 1));
        }
        if (d == 6) await phone.at(on(day, 20), 'logged     Drinks 3', () => phone.log('Drinks', 3));
        if (d == 7) await phone.at(on(day, 20), 'logged     Drinks 2', () => phone.log('Drinks', 2));
        await phone.checkIn(on(day, 21));
      }
      await phone.advanceTo(end);
    });
    expectClean(phone, 'break_habits');
    // Slipped Oct 8 and 9 (two in a row), so the streak restarted on Oct 10
    final smoking = phone.habit('Smoking');
    expect(smoking.wasCompletedOnDate(DateTime(2026, 10, 9)), isFalse);
    expect(smoking.wasCompletedOnDate(DateTime(2026, 10, 10)), isTrue);
    expect(smoking.streak.longest, greaterThanOrEqualTo(smoking.streak.current));
    expect(phone.habit('Drinks').wasCompletedOnDate(DateTime(2026, 10, 3)), isFalse, reason: '3 of at most 2');
    expect(phone.habit('Drinks').wasCompletedOnDate(DateTime(2026, 10, 4)), isTrue, reason: '2 of at most 2');
  });

  test('12. quiet hours: nothing arrives in them; late ones come before, early ones after', () async {
    ReminderSettings at(int hour, [int minute = 0]) => ReminderSettings(
          time: TimeOfDay(hour: hour, minute: minute),
          enabled: true,
          daysOfWeek: const [1, 2, 3, 4, 5, 6, 7],
        );
    final phone = await SimulatedPhone.run(start, (phone) async {
      await phone.at(start, 'quiet      22:00 to 07:00; warnings 1h before, with the early nudge', () async {
        await phone.quietHours(const QuietHours(enabled: true));
        await phone.warnings(lead: const Duration(hours: 1), firstMiss: true);
      });
      await phone.at(start, 'created    Night owl 23:00, Early bird 06:00, Smoking check-in 22:30', () async {
        await phone.create(habit('Night owl', reminder: at(23)));
        await phone.create(habit('Early bird', reminder: at(6)));
        await phone.create(CreateHabitParams(
          name: 'Smoking',
          target: 0,
          color: HabitColor.red,
          categoryId: BuiltInCategoryIds.body,
          goal: HabitGoal.quit,
          resetAnchor: start,
          reminder: at(22, 30),
        ));
      });
      var d = 0;
      for (final day in days()) {
        d++;
        await phone.checkIn(on(day, 7, 30));
        // Done most days, so streaks (and warnings) come and go
        if (d % 4 != 0) await doHabits(phone, on(day, 12), names: ['Night owl', 'Early bird']);
        await phone.checkIn(on(day, 21));
      }
      await phone.advanceTo(end);
    });
    expect(phone.timeline.where((l) => l.contains('REMINDER   Night owl')).every((l) => l.contains('21:45')), isTrue);
    expect(phone.timeline.where((l) => l.contains('REMINDER   Early bird')).every((l) => l.contains('07:00')), isTrue);
    expect(phone.timeline.where((l) => l.contains('REMINDER   Smoking')).every((l) => l.contains('21:45')), isTrue);
    final warnings = phone.timeline.where((l) => l.contains('WARNING') || l.contains('NUDGE'));
    expect(warnings, isNotEmpty);
    expect(warnings.every((l) => l.contains('21:45')), isTrue, reason: '1h before midnight is 23:00, in quiet hours');
    // Wall-clock times, so the same in every zone
    expectClean(phone, 'quiet_hours');
  });

  test('10. clock changes: reminders keep their time, warnings their lead on the clock', () async {
    final phone = await SimulatedPhone.run(start, (phone) async {
      await createAll(phone, [
        habit('Night owl', reminder: ReminderSettings.smart(time: const TimeOfDay(hour: 1, minute: 30))),
        habit('Early bird', reminder: ReminderSettings.smart(time: const TimeOfDay(hour: 2, minute: 15))),
        habit('Morning'),
        habit('Streak', reminder: ReminderSettings.disabled()),
      ]);
      await phone.at(start, 'settings   warn 24 hours before', () => phone.warnings(lead: const Duration(hours: 24)));
      // Streak misses the day before each clock change, so the warning
      // lands on the change day itself
      final misses = {DateTime(2026, 10, 3), DateTime(2026, 10, 24), DateTime(2026, 10, 31)};
      for (final day in days()) {
        await phone.checkIn(on(day, 7, 30));
        if (!misses.contains(day)) await doHabits(phone, on(day, 12), names: ['Streak']);
        if (day == DateTime(2026, 10, 18)) {
          await phone.at(on(day, 13), 'settings   warn 1 hour before', () => phone.warnings(lead: const Duration(hours: 1)));
        }
        if (day == DateTime(2026, 10, 22)) {
          await phone.at(on(day, 13), 'settings   warn 24 hours before', () => phone.warnings(lead: const Duration(hours: 24)));
        }
        await phone.checkIn(on(day, 21));
      }
      await phone.advanceTo(end);
    });
    expect(phone.failures, isEmpty, reason: '\n${phone.failures.join('\n')}');
    // Wall-clock times differ by zone only here; compare in the zones the script runs
    final zone = Platform.environment['TZ'];
    if (_zones.contains(zone)) _expectGolden(phone.timeline, 'clock_changes.${zone!.replaceAll('/', '_')}');
  });
}

/// The zones tool/notification_sim.sh runs the simulation in.
const _zones = ['UTC', 'America/New_York', 'Europe/London', 'Australia/Lord_Howe'];

extension on CreateHabitParams {
  CreateHabitParams withTwoMinute(TwoMinuteVersion tiny) => CreateHabitParams(
        name: name,
        target: target,
        units: units,
        color: color,
        categoryId: categoryId,
        resetFrequency: resetFrequency,
        reminder: reminder,
        icon: icon,
        resetAnchor: resetAnchor,
        resetInterval: resetInterval,
        scheduledWeekdays: scheduledWeekdays,
        twoMinute: tiny,
      );
}

/// Compares [timeline] with its saved copy, or saves it with --update-goldens.
void _expectGolden(List<String> timeline, String name) {
  final zone = Platform.environment['TZ'];
  final file = File('test/simulation/goldens/$name.txt');
  final text = '${timeline.join('\n')}\n';
  if (autoUpdateGoldenFiles) {
    file.createSync(recursive: true);
    file.writeAsStringSync(text);
    return;
  }
  if (!file.existsSync()) fail('No saved timeline for "$name"; run with --update-goldens and review it');
  final saved = file.readAsLinesSync();
  final now = text.trimRight().split('\n');
  final diffs = <String>[];
  for (var i = 0; i < saved.length || i < now.length; i++) {
    final a = i < saved.length ? saved[i] : '(none)';
    final b = i < now.length ? now[i] : '(none)';
    if (a != b) diffs.add('line ${i + 1}\n  saved: $a\n  now:   $b');
    if (diffs.length == 10) break;
  }
  expect(diffs, isEmpty, reason: 'Timeline "$name" changed${zone == null ? '' : ' (TZ=$zone)'}:\n${diffs.join('\n')}');
}
