import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/core/migration/smart_reminders_migration.dart';
import 'package:atomic_momentum/domain/entities/reminder_settings.dart';
import 'package:atomic_momentum/domain/repositories/habit_repository.dart';
import '../../../helpers/test_data.dart';

void main() {
  late HabitRepository repository;
  late SharedPreferences prefs;
  const sevenThirty = TimeOfDay(hour: 7, minute: 30);

  setUp(() async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues({});
    await initializeDependencies(seedDefaultHabit: false);
    repository = get<HabitRepository>();
    prefs = await SharedPreferences.getInstance();
    // initializeDependencies ran it on empty storage; start over
    await prefs.remove(smartRemindersDefaultedKey);
  });

  tearDown(resetDependencies);

  test('habits that never had a reminder get a smart one; turned-off ones stay off', () async {
    const off = ReminderSettings(time: TimeOfDay(hour: 8, minute: 0), enabled: false, daysOfWeek: [1]);
    await repository.saveHabit(TestData.createTestHabit(id: 'none', name: 'None'));
    await repository.saveHabit(TestData.createTestHabit(id: 'off', name: 'Off', reminder: off));

    expect(await enableSmartRemindersOnce(repository: repository, prefs: prefs, time: sevenThirty), 1);

    final none = (await repository.getHabitById('none'))!.reminder!;
    expect(none.mode, ReminderMode.smart);
    expect(none.enabled, isTrue);
    expect(none.time, sevenThirty);
    expect((await repository.getHabitById('off'))!.reminder, off);
  });

  test('runs only once', () async {
    await enableSmartRemindersOnce(repository: repository, prefs: prefs, time: sevenThirty);
    await repository.saveHabit(TestData.createTestHabit(id: 'later', name: 'Later'));

    expect(await enableSmartRemindersOnce(repository: repository, prefs: prefs, time: sevenThirty), 0);
    expect((await repository.getHabitById('later'))!.reminder, isNull);
  });
}
