import 'package:flutter/material.dart';
import '../../core/theme/ios_colors.dart';
import '../../domain/entities/category.dart';
import 'category_icons.dart';

/// Row above the category rings that says what the list is showing and,
/// while a category is selected, offers a way back to all habits.
class CategoryFilterHeader extends StatelessWidget {
  final Category? selected;
  final int habitCount;
  final VoidCallback onShowAll;
  final bool isDark;

  const CategoryFilterHeader({
    Key? key,
    required this.selected,
    required this.habitCount,
    required this.onShowAll,
    required this.isDark,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final category = selected;
    final countText = '$habitCount ${habitCount == 1 ? 'habit' : 'habits'}';
    final labelStyle = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: isDark ? IOSColors.labelDark : IOSColors.label,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
      child: SizedBox(
        // Keeps the row height stable whether or not the button is shown
        height: 44,
        child: Row(
          children: [
            if (category != null) ...[
              Icon(category.icon, size: 18, color: category.color),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                category == null ? 'All habits · $countText' : '${category.name} · $countText',
                key: const Key('filterHeaderLabel'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: labelStyle,
              ),
            ),
            if (category != null)
              TextButton(
                key: const Key('showAllHabits'),
                onPressed: onShowAll,
                style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                child: const Text('Show all'),
              ),
          ],
        ),
      ),
    );
  }
}
