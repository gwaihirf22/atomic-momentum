import '../../domain/entities/category.dart';
import '../../domain/entities/habit_color.dart';
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

  const QuickPick({
    required this.name,
    required this.target,
    required this.units,
    required this.icon,
    required this.color,
    required this.categoryId,
    required this.tiny,
    this.tinyMinimum,
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

  /// Fills [draft] with this pick, every day. The category is used only if
  /// it's still one of [activeCategoryIds].
  void applyTo(HabitDraft draft, Iterable<String> activeCategoryIds) {
    draft.name.text = name;
    draft.target.text = '$target';
    draft.units.text = units;
    draft.tiny.text = tiny;
    draft.tinyMinimum.text = tinyMinimum?.toString() ?? '';
    draft.edit(() {
      draft.icon = icon;
      draft.color = color;
      if (activeCategoryIds.contains(categoryId)) draft.categoryId = categoryId;
      draft.frequency = ResetFrequency.daily;
      draft.interval = 1;
      draft.scheduleDays = List.of(HabitDraft.allDays);
    });
  }

  /// Whether [draft] is (still) this pick, judged by its name.
  bool isChosenIn(HabitDraft draft) => draft.name.text.trim().toLowerCase() == name.toLowerCase();
}
