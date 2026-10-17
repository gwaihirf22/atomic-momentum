import '../../domain/entities/category.dart';
import '../../domain/entities/habit_color.dart';
import '../../domain/entities/habit_goal.dart';
import '../../domain/entities/reset_frequency.dart';
import 'habit_draft.dart';

/// A ready-made habit to start from: one tap fills the name, amount, icon,
/// color, category and a two-minute version, all still editable.
class QuickPick {
  final String name;
  final int target;
  final String units;
  final String icon;
  final HabitColor color;
  final String categoryId;
  final String tiny;
  final int? tinyMinimum;

  /// Build (the default), or a habit to quit or limit; for a limit, [target]
  /// is the most allowed per [frequency].
  final HabitGoal goal;
  final ResetFrequency frequency;

  const QuickPick({
    required this.name,
    required this.target,
    required this.units,
    required this.icon,
    required this.color,
    required this.categoryId,
    this.tiny = '',
    this.tinyMinimum,
    this.goal = HabitGoal.build,
    this.frequency = ResetFrequency.daily,
  });

  static const all = [
    QuickPick(
      name: 'Drink water',
      target: 8,
      units: 'glasses',
      icon: 'water',
      color: HabitColor.blue,
      categoryId: BuiltInCategoryIds.body,
      tiny: 'Fill one glass',
      tinyMinimum: 1,
    ),
    QuickPick(
      name: 'Read',
      target: 10,
      units: 'pages',
      icon: 'book',
      color: HabitColor.teal,
      categoryId: BuiltInCategoryIds.mind,
      tiny: 'Read one page',
      tinyMinimum: 1,
    ),
    QuickPick(
      name: 'Walk',
      target: 20,
      units: 'minutes',
      icon: 'walk',
      color: HabitColor.green,
      categoryId: BuiltInCategoryIds.body,
      tiny: 'Put on your shoes',
    ),
    QuickPick(
      name: 'Meditate',
      target: 1,
      units: 'session',
      icon: 'meditation',
      color: HabitColor.purple,
      categoryId: BuiltInCategoryIds.spirit,
      tiny: 'Take three slow breaths',
    ),
    QuickPick(
      name: 'Stretch',
      target: 1,
      units: 'session',
      icon: 'exercise',
      color: HabitColor.teal,
      categoryId: BuiltInCategoryIds.body,
      tiny: 'One stretch',
    ),
    QuickPick(
      name: 'Journal',
      target: 1,
      units: 'entry',
      icon: 'write',
      color: HabitColor.purple,
      categoryId: BuiltInCategoryIds.mind,
      tiny: 'Write one line',
    ),
  ];

  /// Habits people often want to break.
  static const breaking = [
    QuickPick(
      name: 'Smoking',
      target: 0,
      units: '',
      icon: 'heart',
      color: HabitColor.red,
      categoryId: BuiltInCategoryIds.body,
      goal: HabitGoal.quit,
    ),
    QuickPick(
      name: 'Alcohol',
      target: 2,
      units: 'drinks',
      icon: 'food',
      color: HabitColor.purple,
      categoryId: BuiltInCategoryIds.social,
      goal: HabitGoal.limit,
    ),
    QuickPick(
      name: 'Soda',
      target: 0,
      units: '',
      icon: 'food',
      color: HabitColor.orange,
      categoryId: BuiltInCategoryIds.body,
      goal: HabitGoal.quit,
    ),
    QuickPick(
      name: 'Social media',
      target: 30,
      units: 'minutes',
      icon: 'phone',
      color: HabitColor.blue,
      categoryId: BuiltInCategoryIds.mind,
      goal: HabitGoal.limit,
    ),
    QuickPick(
      name: 'Screens at night',
      target: 60,
      units: 'minutes',
      icon: 'sleep',
      color: HabitColor.indigo,
      categoryId: BuiltInCategoryIds.mind,
      goal: HabitGoal.limit,
    ),
    QuickPick(
      name: 'Late snacking',
      target: 0,
      units: '',
      icon: 'food',
      color: HabitColor.teal,
      categoryId: BuiltInCategoryIds.body,
      goal: HabitGoal.quit,
    ),
  ];

  /// Fills [draft] with this pick, every day. The category is used only if
  /// it's still one of [activeCategoryIds].
  void applyTo(HabitDraft draft, Iterable<String> activeCategoryIds) {
    if (goal != draft.goal) draft.setGoal(goal);
    draft.name.text = name;
    draft.target.text = goal == HabitGoal.quit ? '' : '$target';
    draft.units.text = units;
    draft.tiny.text = tiny;
    draft.tinyMinimum.text = tinyMinimum?.toString() ?? '';
    draft.edit(() {
      draft.icon = icon;
      draft.color = color;
      if (activeCategoryIds.contains(categoryId)) draft.categoryId = categoryId;
      draft.frequency = frequency;
      draft.interval = 1;
      draft.scheduleDays = List.of(HabitDraft.allDays);
    });
  }

  /// Whether [draft] is (still) this pick, judged by its name.
  bool isChosenIn(HabitDraft draft) => draft.name.text.trim().toLowerCase() == name.toLowerCase();
}
