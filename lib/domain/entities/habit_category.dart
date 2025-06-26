import 'package:flutter/material.dart';

enum HabitCategory {
  body("Body", "💪", 0xFF2196F3),
  spirit("Spirit", "🙏", 0xFF9C27B0),
  mind("Mind", "🧠", 0xFF00BCD4),
  social("Social", "👥", 0xFF4CAF50),
  career("Career", "💼", 0xFFFF9800),
  creative("Creative", "🎨", 0xFFE91E63);

  const HabitCategory(this.displayName, this.emoji, this.defaultColorValue);

  final String displayName;
  final String emoji;
  final int defaultColorValue;

  Color get defaultColor => Color(defaultColorValue);

  static HabitCategory fromString(String value) {
    return HabitCategory.values.firstWhere(
      (category) => category.name == value,
      orElse: () => HabitCategory.body,
    );
  }

  @override
  String toString() => name;
}