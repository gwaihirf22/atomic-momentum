import 'package:flutter/cupertino.dart';
import '../../domain/entities/habit_category.dart';

/// The one flat (SF Symbols-style) icon per category, used everywhere in the
/// UI so categories look the same on every screen.
extension HabitCategoryIcon on HabitCategory {
  IconData get icon {
    switch (this) {
      case HabitCategory.body:
        return CupertinoIcons.heart_fill;
      case HabitCategory.spirit:
        return CupertinoIcons.leaf_arrow_circlepath;
      case HabitCategory.mind:
        return CupertinoIcons.book_fill;
      case HabitCategory.social:
        return CupertinoIcons.person_2_fill;
      case HabitCategory.career:
        return CupertinoIcons.briefcase_fill;
      case HabitCategory.creative:
        return CupertinoIcons.paintbrush_fill;
    }
  }
}
