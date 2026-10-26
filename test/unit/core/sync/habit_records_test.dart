import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atomic_momentum/core/sync/habit_records.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/entities/health_link.dart';
import 'package:atomic_momentum/domain/entities/reset_frequency.dart';
import 'package:atomic_momentum/domain/sync/hlc.dart';
import 'package:atomic_momentum/domain/sync/sync_merge.dart';
import 'package:atomic_momentum/domain/sync/sync_records.dart';

/// A device for these tests: its own records, and its copy of each habit.
class Device {
  final String id;
  final HlcClock clock;
  final Records own = {};
  final Map<String, Habit> habits = {};

  Device(this.id) : clock = HlcClock(id);

  /// Records a change, as the app would when it's made.
  void change(Habit? before, Habit? after, World world) {
    final habitId = (after ?? before)!.id;
    final merged = SyncMerge.merge(world.recordsSeenBy(this)).habits[habitId];
    own.addAll(HabitRecords.changes(before: before, after: after, merged: merged, device: id, stamp: clock.tick));
    if (after == null) {
      habits.remove(habitId);
    } else {
      habits[habitId] = after;
    }
  }

  /// Takes in every device's records (a sync).
  void sync(World world) {
    final merged = SyncMerge.merge(world.all());
    for (final records in world.all().values) {
      for (final record in records.values) {
        clock.receive(record.stamp);
      }
    }
    final before = Map.of(habits);
    habits.clear();
    for (final habit in merged.habits.values) {
      final built = HabitRecords.build(habit, local: before[habit.id]);
      if (built != null) habits[habit.id] = built;
    }
  }
}

class World {
  final devices = <String, Device>{};

  /// What each device has, by device.
  Map<String, Records> all() => {for (final d in devices.values) d.id: d.own};

  /// Records [device] has seen: all of them, after a sync (these tests sync
  /// by hand, so this is everything; offline is modelled by not syncing).
  Map<String, Records> recordsSeenBy(Device device) => {device.id: device.own, ...seen[device.id] ?? {}};

  final Map<String, Map<String, Records>> seen = {};

  void syncAll() {
    for (final device in devices.values) {
      seen[device.id] = {for (final other in devices.values) if (other != device) other.id: Map.of(other.own)};
      device.sync(this);
    }
  }
}

final today = DateTime(2026, 10, 25);
DateTime daysAgo(int n) => DateTime(today.year, today.month, today.day - n);

void main() {
  late World world;
  late Device phone;
  late Device ipad;
  var now = DateTime(2026, 10, 25, 12);

  T at<T>(T Function() body) => withClock(Clock(() => now), body);
  void later() => now = now.add(const Duration(minutes: 1));

  setUp(() {
    now = DateTime(2026, 10, 25, 12);
    world = World();
    phone = Device('phone');
    ipad = Device('ipad');
    world.devices
      ..[phone.id] = phone
      ..[ipad.id] = ipad;
  });

  Habit make({String name = 'Drink water', int target = 8, String units = 'glasses', HealthLink? health}) => at(() {
        final made = Habit.create(
          name: name,
          target: target,
          units: units,
          color: HabitColor.blue,
          categoryId: BuiltInCategoryIds.body,
          resetFrequency: ResetFrequency.daily,
        );
        // Made a while ago, so there are days to log
        final started = made.countFrom(daysAgo(20));
        return health == null ? started : started.updateDetails(health: health);
      });

  /// Makes [habit] on [device] and syncs it everywhere.
  Habit add(Device device, Habit habit) {
    at(() => device.change(null, habit, world));
    at(world.syncAll);
    return habit;
  }

  void edit(Device device, String id, Habit Function(Habit) change) {
    later();
    at(() {
      final before = device.habits[id]!;
      device.change(before, change(before), world);
    });
  }

  test('a habit and everything in it comes back the same on the other device', () {
    final habit = at(() => make()
        .setDays({daysAgo(3): 8, daysAgo(2): 5, daysAgo(1): 9})
        .setTwoMinuteForDate(daysAgo(2), true)
        .setDayNote(daysAgo(1), 'Hot day')
        .setWhy('Headaches')
        .freeze(today));
    add(phone, habit);
    final copy = ipad.habits[habit.id]!;
    expect(HabitRecords.fieldsOf(copy), HabitRecords.fieldsOf(habit));
    expect(copy.history, habit.history);
    expect(copy.twoMinuteDays, habit.twoMinuteDays);
    expect(copy.dayNotes, habit.dayNotes);
    expect(copy.frozenDays, habit.frozenDays);
    expect(copy.trackedFrom, habit.trackedFrom);
  });

  test('taps on two devices offline add up; typing a number sets the day', () {
    final habit = add(phone, make());
    edit(phone, habit.id, (h) => h.setDays({today: 3}));
    edit(ipad, habit.id, (h) => h.setDays({today: 1}));
    at(world.syncAll);
    expect(phone.habits[habit.id]!.history[today], 4);
    expect(ipad.habits[habit.id]!.history[today], 4);

    // Typing 6 on the phone means the day holds 6, not 6 + the iPad's 1
    edit(phone, habit.id, (h) => h.setDays({today: 6}));
    at(world.syncAll);
    expect(ipad.habits[habit.id]!.history[today], 6);
    // Clearing the day on the iPad clears it everywhere
    edit(ipad, habit.id, (h) => h.setDays({today: 0}));
    at(world.syncAll);
    expect(phone.habits[habit.id]!.history[today], isNull);
  });

  test('a habit filled in from Health keeps one number a day, never counted twice', () {
    final habit = add(phone, make(health: HealthLink(metric: HealthMetric.water, linkedOn: daysAgo(20))));
    // Water logged in the app goes to Health too, which syncs it to the iPad
    edit(phone, habit.id, (h) => h.setDays({today: 1}));
    at(world.syncAll);
    edit(ipad, habit.id, (h) => h.setDays({today: 2}));
    at(world.syncAll);
    expect(phone.habits[habit.id]!.history[today], 2);
    expect(ipad.habits[habit.id]!.history[today], 2);

    // A day this phone filled in from its own Health, with no records, stays
    phone.habits[habit.id] = phone.habits[habit.id]!.setDays({daysAgo(10): 6});
    at(world.syncAll);
    expect(phone.habits[habit.id]!.history[daysAgo(10)], 6);
    expect(ipad.habits[habit.id]!.history[daysAgo(10)], isNull);
  });

  test('settings: the latest change wins, and a target stays with its units', () {
    final habit = add(phone, make());
    edit(phone, habit.id, (h) => h.updateDetails(name: 'Water'));
    edit(ipad, habit.id, (h) => h.updateDetails(color: HabitColor.green));
    at(world.syncAll);
    expect(phone.habits[habit.id]!.name, 'Water');
    expect(phone.habits[habit.id]!.color, HabitColor.green);
    expect(ipad.habits[habit.id]!.name, 'Water');

    // Units changed on the phone; the iPad's later target change takes the
    // whole amount with it, never 10 of the phone's new units
    edit(phone, habit.id, (h) => h.updateDetails(target: 2000, units: 'ml', historyScale: 250));
    edit(ipad, habit.id, (h) => h.updateDetails(target: 10));
    at(world.syncAll);
    expect(phone.habits[habit.id]!.target, 10);
    expect(phone.habits[habit.id]!.units, 'glasses');
  });

  test('a glass logged offline in the old units is converted after a change of units', () {
    final habit = add(phone, make());
    edit(phone, habit.id, (h) => h.setDays({daysAgo(1): 4}));
    at(world.syncAll);
    // The iPad, offline, logs a glass today; the phone switches to ml
    edit(ipad, habit.id, (h) => h.setDays({today: 1}));
    edit(phone, habit.id, (h) => h.updateDetails(target: 2000, units: 'ml', historyScale: 250));
    edit(phone, habit.id, (h) => h.setDays({today: 500}));
    at(world.syncAll);
    final water = ipad.habits[habit.id]!;
    expect(water.units, 'ml');
    expect(water.history[daysAgo(1)], 1000);
    expect(water.history[today], 750, reason: "the phone's 500 ml and the iPad's glass");
    expect(phone.habits[habit.id]!.history, water.history);
  });

  test('"Counts from" beats an older offline log; a log made after it moves the start back', () {
    final habit = add(phone, make());
    edit(ipad, habit.id, (h) => h.setDays({daysAgo(15): 2}));
    // The phone, not having seen it, counts from 10 days ago
    edit(phone, habit.id, (h) => h.countFrom(daysAgo(10)));
    at(world.syncAll);
    expect(ipad.habits[habit.id]!.history[daysAgo(15)], isNull);
    expect(ipad.habits[habit.id]!.trackedFrom, daysAgo(10));

    // Logging before the start later on moves it back, as it does on one device
    edit(ipad, habit.id, (h) => h.setDays({daysAgo(12): 1}));
    at(world.syncAll);
    expect(phone.habits[habit.id]!.history[daysAgo(12)], 1);
    expect(phone.habits[habit.id]!.trackedFrom, daysAgo(12));
  });

  test('a deleted habit stays deleted, whatever the other device does', () {
    final habit = add(phone, make());
    edit(ipad, habit.id, (h) => h.setDays({today: 2}));
    later();
    at(() => phone.change(phone.habits[habit.id], null, world));
    at(world.syncAll);
    expect(phone.habits, isEmpty);
    expect(ipad.habits, isEmpty);
  });

  test('two devices\' taps never take a day past what a period can hold', () {
    final habit = add(phone, make(target: 2));
    edit(phone, habit.id, (h) => h.setDays({today: 20}));
    edit(ipad, habit.id, (h) => h.setDays({today: 5}));
    at(world.syncAll);
    final copy = ipad.habits[habit.id]!;
    expect(copy.history[today], copy.maxPeriodTotal);
    // And the day can still be changed from there
    edit(ipad, habit.id, (h) => h.setDays({today: 3}));
    at(world.syncAll);
    expect(phone.habits[habit.id]!.history[today], 3);
  });
}
