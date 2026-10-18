import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atomic_momentum/core/exceptions/storage_exceptions.dart';
import 'package:atomic_momentum/data/datasources/shared_preferences_datasource.dart';
import 'package:atomic_momentum/data/models/habit_model.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/entities/reset_frequency.dart';

/// Habits are decoded once and written in one go: a year of history isn't
/// decoded and re-encoded on every tap.
void main() {
  late SharedPreferences prefs;
  late SharedPreferencesDataSource source;

  HabitModel habit(String name, {Map<DateTime, int> history = const {}}) => HabitModel.fromDomain(
        Habit.create(name: name, target: 1, color: HabitColor.blue, categoryId: BuiltInCategoryIds.body)
            .copyWith(history: history),
      );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    source = SharedPreferencesDataSource(prefs);
  });

  List<String> storedNames() =>
      [for (final h in jsonDecode(prefs.getString(SharedPreferencesDataSource.habitsKey)!) as List) h['name'] as String];

  test('reads what it stored, decoding only once', () async {
    await source.saveHabits([habit('Read'), habit('Run')]);
    for (var i = 0; i < 5; i++) {
      expect((await source.getHabits()).map((h) => h.name), ['Read', 'Run']);
    }
    expect(source.decodes, 0, reason: 'what it wrote is what it holds');

    final fresh = SharedPreferencesDataSource(prefs);
    await fresh.getHabits();
    await fresh.getHabits();
    expect(fresh.decodes, 1);
  });

  test('a save replaces one habit and keeps the rest as stored', () async {
    final read = habit('Read', history: {DateTime(2026, 10, 1): 1});
    await source.saveHabits([read, habit('Run')]);
    await source.saveHabit(HabitModel.fromDomain(read.copyWith(history: {DateTime(2026, 10, 1): 1, DateTime(2026, 10, 2): 1})));
    expect(storedNames(), ['Read', 'Run']);
    final again = await SharedPreferencesDataSource(prefs).getHabits();
    expect(again.first.history, hasLength(2));
  });

  test('a write from elsewhere (a backup put back) is read again', () async {
    await source.saveHabits([habit('Read')]);
    final other = SharedPreferencesDataSource(prefs);
    await other.saveHabits([habit('Journal')]);
    expect((await source.getHabits()).map((h) => h.name), ['Read', 'Journal']);
    await prefs.setString(SharedPreferencesDataSource.habitsKey, '[]');
    expect(await source.getHabits(), isEmpty);
  });

  test('deleting writes the rest; deleting what isn\'t there fails', () async {
    final run = habit('Run');
    await source.saveHabits([habit('Read'), run]);
    await source.deleteHabit(run.id);
    expect(storedNames(), ['Read']);
    expect(() => source.deleteHabit('nope'), throwsA(isA<StorageException>()));
  });

  test('a large history is decoded in the background and comes back whole', () async {
    final big = {for (var i = 0; i < 3000; i++) DateTime(2020, 1, 1 + i): 1};
    await prefs.setString(
      SharedPreferencesDataSource.habitsKey,
      jsonEncode([habit('Read', history: big).toCompactJson()]),
    );
    expect(prefs.getString(SharedPreferencesDataSource.habitsKey)!.length,
        greaterThan(SharedPreferencesDataSource.isolateThreshold));
    final loaded = (await source.getHabits()).single;
    expect(loaded.history, hasLength(3000));
    // Constants and enums made in another isolate are still the same ones
    expect(identical(loaded.resetFrequency, ResetFrequency.daily), isTrue);
    expect(loaded.color, HabitColor.blue);
    expect(loaded.schedule.periodStart(DateTime(2026, 1, 1, 12)), DateTime(2026, 1, 1));
  });

  test('corrupt data is a storage error, not a crash', () async {
    await prefs.setString(SharedPreferencesDataSource.habitsKey, '{not json');
    expect(() => source.getHabits(), throwsA(isA<StorageException>()));
  });
}
