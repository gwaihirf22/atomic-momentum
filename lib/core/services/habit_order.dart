import 'package:shared_preferences/shared_preferences.dart';

/// The person's order for their habits (Arrange): a list of habit ids,
/// kept apart from the habits' own storage so reordering never rewrites
/// their histories, and whether habits follow their category's order.
class HabitOrder {
  static const orderKey = 'habit_order_v1';
  static const groupKey = 'habit_group_by_category_v1';

  final SharedPreferences _prefs;
  HabitOrder(this._prefs);

  /// Habit ids in the person's order (empty until they arrange anything).
  List<String> get ids => _prefs.getStringList(orderKey) ?? const [];

  Future<void> setIds(List<String> ids) => _prefs.setStringList(orderKey, ids);

  /// Habits follow their category's order (Paul's default), or any order.
  bool get groupByCategory => _prefs.getBool(groupKey) ?? true;

  Future<void> setGroupByCategory(bool grouped) => _prefs.setBool(groupKey, grouped);
}
