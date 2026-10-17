import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/data/models/habit_model.dart';
import 'package:atomic_momentum/domain/entities/habit.dart';
import '../../../helpers/test_data.dart';

/// The habit's "why" and its day notes.
void main() {
  final now = DateTime(2024, 1, 15, 12);
  DateTime jan(int day) => DateTime(2024, 1, day);
  T at<T>(T Function() body) => withClock(Clock.fixed(now), body);

  test('why is trimmed, cleared with empty text, and has a limit', () {
    final habit = TestData.createTestHabit();
    expect(habit.why, '');
    final withWhy = habit.setWhy('  More energy  ');
    expect(withWhy.why, 'More energy');
    expect(withWhy.setWhy('').why, '');
    expect(() => habit.setWhy('x' * (Habit.maxWhyLength + 1)), throwsArgumentError);
  });

  test('a day note is set, replaced and removed; not on future days', () {
    final habit = TestData.createTestHabit();
    final noted = at(() => habit.setDayNote(DateTime(2024, 1, 14, 18), ' Felt great '));
    expect(noted.dayNotes, {jan(14): 'Felt great'});
    expect(at(() => noted.setDayNote(jan(14), 'Better')).dayNotes, {jan(14): 'Better'});
    expect(at(() => noted.setDayNote(jan(14), '')).dayNotes, isEmpty);
    expect(() => at(() => habit.setDayNote(jan(16), 'Later')), throwsArgumentError);
    expect(() => at(() => habit.setDayNote(jan(14), 'x' * (Habit.maxDayNoteLength + 1))), throwsArgumentError);
  });

  test('notes survive saving and loading, in both formats', () {
    final habit = at(() => TestData.createTestHabit().setWhy('Fewer headaches').setDayNote(jan(14), 'Felt great'));

    final fromEntity = Habit.fromJson(habit.toJson());
    expect(fromEntity.why, 'Fewer headaches');
    expect(fromEntity.dayNotes, {jan(14): 'Felt great'});

    final stored = HabitModel.fromDomain(habit).toJson();
    expect(stored['dayNotes'], {'2024-01-14': 'Felt great'});
    final fromModel = HabitModel.fromJson(stored).toDomain();
    expect(fromModel.why, 'Fewer headaches');
    expect(fromModel.dayNotes, {jan(14): 'Felt great'});
  });

  test('habits saved before notes existed load with none', () {
    final json = HabitModel.fromDomain(TestData.createTestHabit()).toJson()
      ..remove('why')
      ..remove('dayNotes');
    final habit = HabitModel.fromJson(json).toDomain();
    expect(habit.why, '');
    expect(habit.dayNotes, isEmpty);
    expect(HabitModel.fromDomain(habit).toJson().containsKey('dayNotes'), isFalse, reason: 'nothing stored for none');
  });

  test('editing the habit keeps its notes', () {
    final habit = at(() => TestData.createTestHabit().setWhy('Why').setDayNote(jan(14), 'Note'));
    final edited = at(() => habit.updateDetails(name: 'Renamed', target: 4));
    expect(edited.why, 'Why');
    expect(edited.dayNotes, {jan(14): 'Note'});
  });
}
