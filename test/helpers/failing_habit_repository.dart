import 'package:atomic_momentum/core/exceptions/storage_exceptions.dart';
import 'package:atomic_momentum/data/datasources/local_habit_datasource.dart';
import 'package:atomic_momentum/data/repositories/habit_repository_impl.dart';
import 'package:atomic_momentum/domain/entities/habit.dart';

/// Real repository whose saves can be made to fail, to test error handling.
class FailingHabitRepository extends HabitRepositoryImpl {
  FailingHabitRepository(LocalHabitDataSource dataSource) : super(dataSource);

  bool failSaves = false;

  @override
  Future<void> saveHabit(Habit habit) async {
    if (failSaves) throw StorageException('Disk full');
    return super.saveHabit(habit);
  }
}
