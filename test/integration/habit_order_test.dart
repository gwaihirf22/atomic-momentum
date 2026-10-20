import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/core/services/habit_order.dart';
import 'package:atomic_momentum/data/datasources/shared_preferences_datasource.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/usecases/create_habit_usecase.dart';
import 'package:atomic_momentum/domain/usecases/update_habit_usecase.dart';
import 'package:atomic_momentum/presentation/providers/category_provider.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late HabitProvider habits;
  late CategoryProvider categories;

  Future<void> start([Map<String, Object> values = const {}]) async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues(values);
    await initializeDependencies(seedDefaultHabit: false);
    habits = get<HabitProvider>();
    categories = get<CategoryProvider>();
    await habits.loadHabits();
  }

  Future<void> add(String name, String category) => habits.createHabit(
      CreateHabitParams(name: name, target: 1, color: HabitColor.blue, categoryId: category));

  List<String> names() => [for (final h in habits.habits) h.name];
  String id(String name) => habits.habits.firstWhere((h) => h.name == name).id;
  Map<String, Object> stored() {
    final prefs = get<SharedPreferences>();
    return {for (final k in prefs.getKeys()) k: prefs.get(k)!};
  }

  setUp(() async {
    await start();
    // Added out of category order on purpose
    await add('Read', BuiltInCategoryIds.mind);
    await add('Water', BuiltInCategoryIds.body);
    await add('Pray', BuiltInCategoryIds.spirit);
    await add('Gym', BuiltInCategoryIds.body);
  });

  tearDown(resetDependencies);

  test('habits start grouped by category, in the categories\' order, oldest first', () {
    expect(names(), ['Water', 'Gym', 'Pray', 'Read']);
  });

  test('reordering categories moves their habits', () async {
    // Spirit to the top
    final spirit = categories.categories.indexWhere((c) => c.id == BuiltInCategoryIds.spirit);
    await categories.reorder(spirit, 0);
    expect(names(), ['Pray', 'Water', 'Gym', 'Read']);
  });

  test('moving a habit saves only the order, and a relaunch keeps it', () async {
    final habitsBefore = get<SharedPreferences>().getString(SharedPreferencesDataSource.habitsKey);
    await habits.moveHabit(id('Gym'), 0);
    expect(names(), ['Gym', 'Water', 'Pray', 'Read']);
    expect(get<SharedPreferences>().getString(SharedPreferencesDataSource.habitsKey), habitsBefore,
        reason: "the habits themselves aren't rewritten");

    await start(stored());
    expect(names(), ['Gym', 'Water', 'Pray', 'Read']);
  });

  test('a new habit goes at the end of its category', () async {
    await habits.moveHabit(id('Gym'), 0);
    await add('Stretch', BuiltInCategoryIds.body);
    expect(names(), ['Gym', 'Water', 'Stretch', 'Pray', 'Read']);
  });

  test('a habit moved to another category goes to the end of it', () async {
    await habits.updateHabitDetails(id('Water'), const UpdateHabitParams(categoryId: BuiltInCategoryIds.mind));
    expect(names(), ['Gym', 'Pray', 'Read', 'Water']);
  });

  test('a deleted category\'s habits go to Uncategorized, last', () async {
    await categories.delete(BuiltInCategoryIds.body);
    expect(names(), ['Pray', 'Read', 'Water', 'Gym']);
  });

  test('turning grouping off keeps the order as shown; then any order goes', () async {
    await habits.setGroupByCategory(false);
    expect(names(), ['Water', 'Gym', 'Pray', 'Read']);
    await habits.moveHabit(id('Read'), 1);
    expect(names(), ['Water', 'Read', 'Gym', 'Pray']);
    // Categories no longer move habits
    final spirit = categories.categories.indexWhere((c) => c.id == BuiltInCategoryIds.spirit);
    await categories.reorder(spirit, 0);
    expect(names(), ['Water', 'Read', 'Gym', 'Pray']);
    // And back on: grouped again, keeping the order within each category
    await habits.setGroupByCategory(true);
    expect(names(), ['Pray', 'Water', 'Gym', 'Read']);
    expect(HabitOrder(get<SharedPreferences>()).groupByCategory, isTrue);
  });

  test('deleting a habit drops it from the order', () async {
    await habits.moveHabit(id('Gym'), 0);
    final gym = id('Gym');
    await habits.deleteHabit(gym);
    expect(HabitOrder(get<SharedPreferences>()).ids, isNot(contains(gym)));
    expect(names(), ['Water', 'Pray', 'Read']);
  });
}
