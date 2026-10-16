import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/core/services/streak_warning_service.dart';
import 'package:atomic_momentum/domain/entities/streak_warning_settings.dart';
import 'package:atomic_momentum/domain/entities/habit.dart';
import 'package:atomic_momentum/domain/entities/habit_category.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/entities/reset_frequency.dart';
import 'package:atomic_momentum/domain/repositories/habit_repository.dart';
import 'package:atomic_momentum/domain/usecases/get_habits_usecase.dart';
import 'package:atomic_momentum/domain/usecases/create_habit_usecase.dart';
import 'package:atomic_momentum/domain/usecases/update_habit_usecase.dart';
import 'package:atomic_momentum/domain/usecases/delete_habit_usecase.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';
import 'package:atomic_momentum/presentation/providers/category_provider.dart';

import 'package:atomic_momentum/data/datasources/local_habit_datasource.dart';

import '../helpers/failing_habit_repository.dart';
import '../helpers/fake_streak_warning_scheduler.dart';

void main() {
  group('Data Flow Integration Tests', () {
    setUp(() async {
      // Clear any existing registrations
      await resetDependencies();
      
      // Set up in-memory SharedPreferences for testing
      SharedPreferences.setMockInitialValues({});
      
      // Initialize dependencies with real implementations
      await initializeDependencies(seedDefaultHabit: false);
    });

    tearDown(() async {
      await resetDependencies();
    });

    group('Complete Habit Lifecycle', () {
      test('should create, update, and delete habit through complete flow', () async {
        // Get use cases
        final getHabitsUseCase = get<GetHabitsUseCase>();
        final createHabitUseCase = get<CreateHabitUseCase>();
        final updateHabitUseCase = get<UpdateHabitUseCase>();
        final deleteHabitUseCase = get<DeleteHabitUseCase>();

        // 1. Initial state - no habits
        var habits = await getHabitsUseCase();
        expect(habits, isEmpty);

        // 2. Create a habit
        final createParams = CreateHabitParams(
          name: 'Test Habit',
          target: 10,
          color: HabitColor.blue,
          category: HabitCategory.body,
        );

        final createdHabit = await createHabitUseCase(createParams);
        expect(createdHabit.name, 'Test Habit');
        expect(createdHabit.progress, 0);
        expect(createdHabit.target, 10);

        // 3. Verify habit was saved
        habits = await getHabitsUseCase();
        expect(habits, hasLength(1));
        expect(habits.first.id, createdHabit.id);

        // 4. Update habit progress
        final updatedHabit = await updateHabitUseCase.updateProgress(createdHabit.id, 5);
        expect(updatedHabit.progress, 5);
        expect(updatedHabit.history, hasLength(1));

        // 5. Verify progress was saved
        habits = await getHabitsUseCase();
        expect(habits.first.progress, 5);

        // 6. Update habit details
        final updateParams = UpdateHabitParams(
          name: 'Updated Test Habit',
          target: 15,
          color: HabitColor.green,
        );

        final updatedHabitDetails = await updateHabitUseCase.updateDetails(createdHabit.id, updateParams);
        expect(updatedHabitDetails.name, 'Updated Test Habit');
        expect(updatedHabitDetails.target, 15);
        expect(updatedHabitDetails.color, HabitColor.green);

        // 7. Verify details were saved
        habits = await getHabitsUseCase();
        expect(habits.first.name, 'Updated Test Habit');
        expect(habits.first.target, 15);

        // 8. Delete habit
        await deleteHabitUseCase(createdHabit.id);

        // 9. Verify habit was deleted
        habits = await getHabitsUseCase();
        expect(habits, isEmpty);
      });

      test('should handle multiple habits correctly', () async {
        final getHabitsUseCase = get<GetHabitsUseCase>();
        final createHabitUseCase = get<CreateHabitUseCase>();
        final deleteHabitUseCase = get<DeleteHabitUseCase>();

        // Ensure clean state - delete any existing habits
        final existingHabits = await getHabitsUseCase();
        for (final habit in existingHabits) {
          await deleteHabitUseCase(habit.id);
        }

        // Create multiple habits
        final habits = <Habit>[];
        for (int i = 1; i <= 5; i++) {  // Start from 1 to avoid any issues with 0
          final params = CreateHabitParams(
            name: 'Habit $i',
            target: i + 1,
            color: HabitColor.predefinedColors[i % HabitColor.predefinedColors.length],
            category: HabitCategory.values[i % HabitCategory.values.length],
          );
          
          final habit = await createHabitUseCase(params);
          habits.add(habit);
        }

        // Verify all habits were created
        final savedHabits = await getHabitsUseCase();
        expect(savedHabits, hasLength(5));

        // Each habit kept its category
        for (final habit in habits) {
          expect(savedHabits.firstWhere((h) => h.id == habit.id).category, habit.category);
        }
      });
    });

    group('Provider Integration', () {
      test('should work correctly with HabitProvider', () async {
        final habitProvider = get<HabitProvider>();

        // Initial load
        await habitProvider.loadHabits();
        expect(habitProvider.state, HabitProviderState.loaded);
        expect(habitProvider.habits, isEmpty);

        // Create habit through provider
        final createParams = CreateHabitParams(
          name: 'Provider Test Habit',
          target: 8,
          color: HabitColor.purple,
          category: HabitCategory.mind,
        );

        final success = await habitProvider.createHabit(createParams);
        expect(success, isTrue);
        expect(habitProvider.habits, hasLength(1));

        final createdHabit = habitProvider.habits.first;
        expect(createdHabit.name, 'Provider Test Habit');

        // Update progress through provider
        final updateSuccess = await habitProvider.updateHabitProgress(createdHabit.id, 3);
        expect(updateSuccess, isTrue);
        expect(habitProvider.habits.first.progress, 3);

        // Delete through provider
        final deleteSuccess = await habitProvider.deleteHabit(createdHabit.id);
        expect(deleteSuccess, isTrue);
        expect(habitProvider.habits, isEmpty);
      });

      test('should work correctly with CategoryProvider', () async {
        final habitProvider = get<HabitProvider>();
        final categoryProvider = get<CategoryProvider>();

        // Create habits in different categories
        await habitProvider.loadHabits();

        final bodyHabitParams = CreateHabitParams(
          name: 'Body Habit',
          target: 5,
          color: HabitColor.orange,
          category: HabitCategory.body,
        );

        final mindHabitParams = CreateHabitParams(
          name: 'Mind Habit',
          target: 3,
          color: HabitColor.blue,
          category: HabitCategory.mind,
        );

        await habitProvider.createHabit(bodyHabitParams);
        await habitProvider.createHabit(mindHabitParams);

        // Test category filtering
        categoryProvider.setSelectedCategory(HabitCategory.body);
        final filteredHabits = categoryProvider.filterHabits(habitProvider.habits);
        expect(filteredHabits, hasLength(1));
        expect(filteredHabits.first.category, HabitCategory.body);

        // Test category stats
        final stats = categoryProvider.getCategoryStats(habitProvider.habits);
        expect(stats[HabitCategory.body]?.totalHabits, 1);
        expect(stats[HabitCategory.mind]?.totalHabits, 1);
      });
    });

    group('Data Persistence', () {
      test('should persist data across provider instances', () async {
        // Create habit with first provider instance
        final habitProvider1 = get<HabitProvider>();
        await habitProvider1.loadHabits();

        final createParams = CreateHabitParams(
          name: 'Persistent Habit',
          target: 12,
          color: HabitColor.red,
          category: HabitCategory.career,
        );

        await habitProvider1.createHabit(createParams);
        expect(habitProvider1.habits, hasLength(1));

        // Create new provider instance and verify data persists
        final habitProvider2 = HabitProvider(
          getHabitsUseCase: get<GetHabitsUseCase>(),
          createHabitUseCase: get<CreateHabitUseCase>(),
          updateHabitUseCase: get<UpdateHabitUseCase>(),
          deleteHabitUseCase: get<DeleteHabitUseCase>(),
        );

        await habitProvider2.loadHabits();
        expect(habitProvider2.habits, hasLength(1));
        expect(habitProvider2.habits.first.name, 'Persistent Habit');
      });

      test('should handle concurrent operations correctly', () async {
        final habitProvider = get<HabitProvider>();
        await habitProvider.loadHabits();

        // Create multiple habits concurrently
        final createFutures = <Future<bool>>[];
        for (int i = 0; i < 3; i++) {
          final params = CreateHabitParams(
            name: 'Concurrent Habit $i',
            target: i + 1,
            color: HabitColor.blue,
            category: HabitCategory.body,
          );
          createFutures.add(habitProvider.createHabit(params));
        }

        final results = await Future.wait(createFutures);
        expect(results.every((success) => success), isTrue);
        expect(habitProvider.habits, hasLength(3));
      });
    });

    group('Error Handling', () {
      test('should handle invalid habit creation gracefully', () async {
        final createHabitUseCase = get<CreateHabitUseCase>();

        // Try to create habit with empty name
        final invalidParams = CreateHabitParams(
          name: '',
          target: 5,
          color: HabitColor.blue,
          category: HabitCategory.body,
        );

        expect(
          () => createHabitUseCase(invalidParams),
          throwsA(isA<Exception>()),
        );
      });

      test('should handle repository errors in provider', () async {
        final habitProvider = get<HabitProvider>();

        // Try to update non-existent habit
        final success = await habitProvider.updateHabitProgress('non_existent_id', 5);
        expect(success, isFalse);
        expect(habitProvider.error, isNotNull);
      });
    });

    group('Period Reset', () {
      test('should reset stale habit progress on load and keep its history', () async {
        final createHabitUseCase = get<CreateHabitUseCase>();
        final updateHabitUseCase = get<UpdateHabitUseCase>();
        final repository = get<HabitRepository>();

        final habit = await createHabitUseCase(CreateHabitParams(
          name: 'Daily Water',
          target: 8,
          color: HabitColor.blue,
          category: HabitCategory.body,
          resetFrequency: ResetFrequency.daily,
        ));
        final progressed = await updateHabitUseCase.updateProgress(habit.id, 5);

        // Simulate the progress having been logged yesterday
        final now = DateTime.now();
        final yesterday = DateTime(now.year, now.month, now.day - 1);
        await repository.saveHabit(progressed.copyWith(
          lastUpdatedDate: yesterday,
          history: {yesterday: 5},
        ));

        final habitProvider = get<HabitProvider>();
        await habitProvider.loadHabits();

        final reloaded = habitProvider.getHabitById(habit.id)!;
        expect(reloaded.progress, 0);
        expect(reloaded.history, isNotEmpty);
      });

      test('should keep progress for a weekly habit within the same week', () async {
        final createHabitUseCase = get<CreateHabitUseCase>();
        final updateHabitUseCase = get<UpdateHabitUseCase>();

        final habit = await createHabitUseCase(CreateHabitParams(
          name: 'Weekly Run',
          target: 3,
          color: HabitColor.green,
          category: HabitCategory.body,
          resetFrequency: ResetFrequency.weekly,
        ));
        await updateHabitUseCase.updateProgress(habit.id, 2);

        final habitProvider = get<HabitProvider>();
        await habitProvider.loadHabits();

        expect(habitProvider.getHabitById(habit.id)!.progress, 2);
      });
    });

    group('Retroactive edits and streak warnings', () {
      test('filling in past days rebuilds the streak and schedules a warning', () async {
        final scheduler = FakeStreakWarningScheduler();
        final habitProvider = HabitProvider(
          getHabitsUseCase: get<GetHabitsUseCase>(),
          createHabitUseCase: get<CreateHabitUseCase>(),
          updateHabitUseCase: get<UpdateHabitUseCase>(),
          deleteHabitUseCase: get<DeleteHabitUseCase>(),
          streakWarningService: StreakWarningService(
            scheduler: scheduler,
            readSettings: () => StreakWarningSettings.defaults,
          ),
        );
        await habitProvider.loadHabits();

        await habitProvider.createHabit(CreateHabitParams(
          name: 'Meditate',
          target: 1,
          color: HabitColor.purple,
          category: HabitCategory.spirit,
        ));
        final id = habitProvider.habits.single.id;

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        DateTime daysAgo(int n) => DateTime(today.year, today.month, today.day - n);

        // Days 3 and 1 ago logged, day 2 forgotten
        expect(await habitProvider.updateProgressForDate(id, daysAgo(3), 1), isTrue);
        expect(await habitProvider.updateProgressForDate(id, daysAgo(1), 1), isTrue);
        expect(habitProvider.getHabitById(id)!.streak.current, 1);

        // Retroactively fill the gap
        await habitProvider.updateProgressForDate(id, daysAgo(2), 1);
        expect(habitProvider.getHabitById(id)!.streak.current, 3);

        // Completing today means the next deadline is the end of tomorrow
        await habitProvider.updateHabitProgress(id, 1);
        expect(habitProvider.getHabitById(id)!.streak.current, 4);
        expect(
          scheduler.scheduled[id]!.at,
          DateTime(today.year, today.month, today.day + 2).subtract(const Duration(hours: 4)),
        );

        // The streak survives a reload from storage
        await habitProvider.loadHabits();
        expect(habitProvider.getHabitById(id)!.streak.current, 4);

        await habitProvider.deleteHabit(id);
        expect(scheduler.scheduled, isEmpty);
      });

      test('rejects editing a future day', () async {
        final habitProvider = get<HabitProvider>();
        await habitProvider.createHabit(CreateHabitParams(
          name: 'Stretch',
          target: 1,
          color: HabitColor.teal,
          category: HabitCategory.body,
        ));
        final id = habitProvider.habits.single.id;

        final tomorrow = DateTime.now().add(const Duration(days: 1));
        expect(await habitProvider.updateProgressForDate(id, tomorrow, 1), isFalse);
        expect(habitProvider.error, contains('future'));
      });

      test('a chosen reset day is saved and drives weekly resets', () async {
        final createHabitUseCase = get<CreateHabitUseCase>();
        final getHabitsUseCase = get<GetHabitsUseCase>();
        final thursday = DateTime(2024, 1, 18);

        final created = await createHabitUseCase(CreateHabitParams(
          name: 'Long run',
          target: 1,
          color: HabitColor.red,
          category: HabitCategory.body,
          resetFrequency: ResetFrequency.weekly,
          resetAnchor: thursday,
        ));

        final saved = (await getHabitsUseCase()).single;
        expect(saved.id, created.id);
        expect(saved.resetAnchor, thursday);
        expect(
          saved.resetFrequency.periodStart(DateTime.now(), anchor: saved.resetAnchor).weekday,
          DateTime.thursday,
        );
      });
    });

    group('Sample habits', () {
      test('adds one per category, skips existing names, and seeds a streak', () async {
        final habitProvider = get<HabitProvider>();
        await habitProvider.loadHabits();
        await habitProvider.createHabit(CreateHabitParams(
          name: 'Drink Water',
          target: 5,
          color: HabitColor.red,
          category: HabitCategory.body,
        ));

        expect(await habitProvider.addSampleHabits(), 5);
        expect(habitProvider.habits, hasLength(6));
        expect(habitProvider.habits.map((h) => h.category).toSet(), HabitCategory.values.toSet());
        // The user's own Drink Water is untouched
        expect(habitProvider.habits.firstWhere((h) => h.name == 'Drink Water').target, 5);

        // Days 2 and 1 ago completed (3 ago is a gap) -> 2-day streak
        expect(habitProvider.habits.firstWhere((h) => h.name == 'Meditate').streak.current, 2);

        expect(await habitProvider.addSampleHabits(), 0);
        expect(habitProvider.habits, hasLength(6));
      });

      test('empty storage is seeded with all samples when seeding is on', () async {
        final habitProvider = HabitProvider(
          getHabitsUseCase: get<GetHabitsUseCase>(),
          createHabitUseCase: get<CreateHabitUseCase>(),
          updateHabitUseCase: get<UpdateHabitUseCase>(),
          deleteHabitUseCase: get<DeleteHabitUseCase>(),
          seedDefaultHabit: true,
        );
        await habitProvider.loadHabits();

        expect(habitProvider.habits, hasLength(6));
      });
    });

    group('Save failures', () {
      test('a failed progress save is reported and not shown as saved', () async {
        final repository = FailingHabitRepository(get<LocalHabitDataSource>());
        final habitProvider = HabitProvider(
          getHabitsUseCase: GetHabitsUseCase(repository),
          createHabitUseCase: CreateHabitUseCase(repository),
          updateHabitUseCase: UpdateHabitUseCase(repository),
          deleteHabitUseCase: DeleteHabitUseCase(repository),
        );
        await habitProvider.createHabit(CreateHabitParams(
          name: 'Water',
          target: 8,
          color: HabitColor.blue,
          category: HabitCategory.body,
        ));
        final id = habitProvider.habits.single.id;

        repository.failSaves = true;
        final success = await habitProvider.updateHabitProgress(id, 3);

        expect(success, isFalse);
        expect(habitProvider.error, isNotNull);
        expect(habitProvider.getHabitById(id)!.progress, 0, reason: 'UI must not show unsaved progress');

        repository.failSaves = false;
        await habitProvider.loadHabits();
        expect(habitProvider.getHabitById(id)!.progress, 0);
      });
    });

    group('JSON Serialization Integration', () {
      test('should correctly serialize and deserialize habits', () async {
        final habitProvider = get<HabitProvider>();
        await habitProvider.loadHabits();

        // Create a complex habit with all fields
        final createParams = CreateHabitParams(
          name: 'Complex Habit',
          target: 20,
          color: HabitColor.green,
          category: HabitCategory.creative,
        );

        await habitProvider.createHabit(createParams);
        final createdHabit = habitProvider.habits.first;

        // Update progress to create history
        await habitProvider.updateHabitProgress(createdHabit.id, 10);
        await habitProvider.updateHabitProgress(createdHabit.id, 15);

        // Reload habits and verify data integrity
        await habitProvider.refreshHabits();
        final reloadedHabit = habitProvider.habits.first;

        expect(reloadedHabit.id, createdHabit.id);
        expect(reloadedHabit.name, 'Complex Habit');
        expect(reloadedHabit.progress, 15);
        expect(reloadedHabit.target, 20);
        expect(reloadedHabit.category, HabitCategory.creative);
        expect(reloadedHabit.history, isNotEmpty);
      });
    });
  });
}