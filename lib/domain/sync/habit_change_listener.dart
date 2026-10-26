import '../entities/habit.dart';

/// Told about each change to a habit as it's made (sync records it).
abstract interface class HabitChangeListener {
  /// [before] null: just made; [after] null: deleted.
  void habitChanged(Habit? before, Habit? after);
}
