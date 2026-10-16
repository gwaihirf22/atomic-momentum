import 'package:flutter/material.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/habit.dart';
import 'category_icons.dart';

/// Icons a habit can be given, keyed by the string stored in
/// `habit.metadata.icon`. Map order is the order shown in the picker.
class HabitIcons {
  const HabitIcons._();

  static const Map<String, IconData> library = {
    'water': Icons.local_drink,
    'exercise': Icons.fitness_center,
    'book': Icons.menu_book,
    'meditation': Icons.self_improvement,
    'sleep': Icons.bedtime,
    'food': Icons.restaurant,
    'pill': Icons.medication,
    'run': Icons.directions_run,
    'bike': Icons.directions_bike,
    'music': Icons.music_note,
    'phone': Icons.phone,
    'heart': Icons.favorite,
    'work': Icons.work,
    'study': Icons.school,
    'clean': Icons.cleaning_services,
    'walk': Icons.directions_walk,
    'write': Icons.edit,
    'money': Icons.attach_money,
    'check': Icons.check_circle,
    'star': Icons.star,
  };

  /// Null when [key] is null or not in the library.
  static IconData? of(String? key) => key == null ? null : library[key];
}

/// The icon to show for [habit]: its chosen icon, otherwise its category's.
IconData habitIcon(Habit habit, Category category) =>
    HabitIcons.of(habit.metadata.icon) ?? category.icon;
