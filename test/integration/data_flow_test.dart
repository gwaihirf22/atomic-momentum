import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../lib/core/injection/injection_container.dart';
import '../../lib/domain/entities/habit.dart';
import '../../lib/domain/entities/habit_category.dart';
import '../../lib/domain/entities/habit_color.dart';
import '../../lib/domain/usecases/get_habits_usecase.dart';
import '../../lib/domain/usecases/create_habit_usecase.dart';
import '../../lib/domain/usecases/update_habit_usecase.dart';
import '../../lib/domain/usecases/delete_habit_usecase.dart';
import '../../lib/presentation/providers/habit_provider.dart';
import '../../lib/presentation/providers/category_provider.dart';

void main() {
  group('Data Flow Integration Tests', () {
    setUp(() async {
      // Clear any existing registrations
      await resetDependencies();
      
      // Set up in-memory SharedPreferences for testing
      SharedPreferences.setMockInitialValues({});
      
      // Initialize dependencies with real implementations
      await initializeDependencies();
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

        // Create multiple habits
        final habits = <Habit>[];
        for (int i = 0; i < 5; i++) {
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

        // Verify habits by category
        for (final category in HabitCategory.values) {
          final categoryHabits = await getHabitsUseCase.byCategory(category);
          final expectedCount = habits.where((h) => h.category == category).length;
          expect(categoryHabits, hasLength(expectedCount));
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