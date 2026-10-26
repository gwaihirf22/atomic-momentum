import 'package:clock/clock.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../../core/feedback/haptics.dart';
import '../../core/theme/app_palette.dart';
import 'large_title_scaffold.dart' show LargeTitleHeader;
import '../providers/category_provider.dart';
import '../providers/habit_provider.dart';
import '../tour/tour_anchor.dart';
import '../tour/tour_events.dart';
import 'category_icons.dart';
import 'floating_tab_bar.dart';

/// The iPad's navigation, in place of the floating tab bar when there's
/// room (a regular or wide window): Add habit, the sections, and the
/// person's categories under Habits, which filter the Habits list as the
/// rings at its top do. Keys and tour anchors match the tab bar's
/// (`tab_habits`, `addHabitButton`, [TourAnchorId.tabBar],
/// [TourAnchorId.addHabit]), so tours, tests and requests from outside work
/// the same.
class AppSidebar extends StatelessWidget {
  static const width = 264.0;

  /// The sections, in order (Inspire only while it's on).
  final List<FloatingTab> tabs;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onAdd;

  /// A category under Habits was chosen: show Habits, filtered to it.
  final ValueChanged<String> onCategory;

  /// A category under Habits was held: open Arrange there.
  final ValueChanged<String> onArrangeCategory;

  const AppSidebar({
    super.key,
    required this.tabs,
    required this.currentIndex,
    required this.onTap,
    required this.onAdd,
    required this.onCategory,
    required this.onArrangeCategory,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final categories = context.watch<CategoryProvider>();
    final habits = context.watch<HabitProvider>().habits;
    final options = categories.filterOptions(habits);
    final stats = categories.getCategoryStats(habits.where((h) => h.isDueOn(clock.now())).toList());
    final habitsSelected = currentIndex == 0;

    return Container(
      key: const Key('appSidebar'),
      width: width,
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(right: BorderSide(color: palette.separator, width: 0.5)),
      ),
      child: SafeArea(
        right: false,
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.6,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
                child: Text(
                  'Momentum',
                  style: TextStyle(
                    fontFamily: LargeTitleHeader.fontFamily,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: palette.text,
                  ),
                ),
              ),
              _AddButton(onAdd: onAdd),
              const SizedBox(height: 14),
              TourAnchor(
                id: TourAnchorId.tabBar,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < tabs.length; i++) ...[
                      _SidebarRow(
                        key: Key('tab_${tabs[i].label.toLowerCase()}'),
                        icon: i == currentIndex ? tabs[i].activeIcon : tabs[i].icon,
                        label: tabs[i].label,
                        selected: i == currentIndex && (i != 0 || categories.selectedCategoryId == null),
                        onTap: () {
                          Haptics.selection();
                          // Habits itself shows every habit
                          if (i == 0) categories.clearSelectedCategory();
                          onTap(i);
                        },
                      ),
                      if (i == 0)
                        for (final category in options)
                          _SidebarRow(
                            key: Key('sidebarCategory_${category.id}'),
                            icon: category.icon,
                            iconColor: palette.habitColor(category.color),
                            label: category.name,
                            trailing: _count(stats[category.id]),
                            indent: true,
                            selected: habitsSelected && categories.selectedCategoryId == category.id,
                            onTap: () {
                              Haptics.selection();
                              onCategory(category.id);
                            },
                            onLongPress: () => onArrangeCategory(category.id),
                          ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// "2/5": a category's habits done of those due today.
  static String? _count(CategoryStats? stats) =>
      stats == null || stats.totalHabits == 0 ? null : '${stats.completedHabits}/${stats.totalHabits}';
}

/// "+ Add habit", the app's add button where the tab bar would have it.
class _AddButton extends StatelessWidget {
  final VoidCallback onAdd;

  const _AddButton({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    void tap() {
      Haptics.selection();
      TourEvents.emit(const AddHabitTapped());
      onAdd();
    }

    return Semantics(
      button: true,
      label: 'Add habit',
      hint: 'Adds a new habit',
      excludeSemantics: true,
      onTap: tap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: tap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              TourAnchor(
                id: TourAnchorId.addHabit,
                child: Container(
                  key: const Key('addHabitButton'),
                  width: FloatingTabBar.addOrbSize,
                  height: FloatingTabBar.addOrbSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: palette.orb,
                    boxShadow: [BoxShadow(color: palette.orbShadow, blurRadius: 10, offset: const Offset(0, 3))],
                  ),
                  child: const Icon(CupertinoIcons.add, size: 22, color: AppPalette.onOrb),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Add habit',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: palette.accent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarRow extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final String? trailing;
  final bool selected;
  final bool indent;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _SidebarRow({
    super.key,
    required this.icon,
    this.iconColor,
    required this.label,
    this.trailing,
    required this.selected,
    this.indent = false,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final color = selected ? palette.accent : palette.text;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      onLongPress: onLongPress,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 1),
          constraints: const BoxConstraints(minHeight: 44),
          padding: EdgeInsets.fromLTRB(indent ? 30 : 10, 8, 10, 8),
          decoration: BoxDecoration(
            color: selected ? palette.goldTint : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, size: indent ? 18 : 22, color: iconColor ?? color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: indent ? 15 : 17,
                    fontWeight: selected ? FontWeight.w700 : (indent ? FontWeight.w500 : FontWeight.w600),
                    color: color,
                  ),
                ),
              ),
              if (trailing != null)
                Text(trailing!, style: TextStyle(fontSize: 13, color: palette.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}
