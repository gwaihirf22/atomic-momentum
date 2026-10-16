import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../domain/entities/category.dart';
import '../domain/entities/habit.dart';
import '../presentation/providers/category_provider.dart';
import '../presentation/providers/habit_provider.dart';
import '../presentation/widgets/category_editor_sheet.dart';
import '../presentation/widgets/category_icons.dart';
import '../presentation/widgets/adaptive.dart';
import 'package:flutter/cupertino.dart';
import '../core/theme/app_style.dart';

/// Manage categories: add, edit, reorder, delete, and restore or
/// permanently remove deleted ones.
class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final categoryProvider = context.watch<CategoryProvider>();
    final habits = context.watch<HabitProvider>().habits;
    final categories = categoryProvider.categories;
    final atLimit = categories.length >= Category.maxCount;

    final addButton = IconButton(
      key: const Key('addCategory'),
      icon: Icon(isCupertino(context) ? CupertinoIcons.add : Icons.add),
      tooltip: atLimit ? 'You can have up to ${Category.maxCount} categories' : 'Add category',
      onPressed: atLimit ? null : () => showCategoryEditorSheet(context),
    );
    return Scaffold(
      appBar: isCupertino(context)
          ? CupertinoNavigationBar(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              middle: const Text('Categories'),
              trailing: addButton,
            )
          : AppBar(title: const Text('Categories'), actions: [addButton]) as PreferredSizeWidget,
      body: ReorderableListView(
        buildDefaultDragHandles: false,
        onReorder: (oldIndex, newIndex) => _reorder(context, oldIndex, newIndex),
        footer: _Footer(atLimit: atLimit, habits: habits),
        children: [
          for (var i = 0; i < categories.length; i++)
            _CategoryRow(
              key: Key('categoryRow_${categories[i].id}'),
              category: categories[i],
              index: i,
              habitCount: _countHabits(habits, categories[i].id),
            ),
        ],
      ),
    );
  }

  Future<void> _reorder(BuildContext context, int oldIndex, int newIndex) async {
    final provider = context.read<CategoryProvider>();
    if (!await provider.reorder(oldIndex, newIndex) && context.mounted) {
      _showMessage(context, provider.error ?? 'Could not reorder categories');
    }
  }
}

int _countHabits(List<Habit> habits, String categoryId) =>
    habits.where((h) => h.categoryId == categoryId).length;

String _habitCountText(int count) =>
    count == 0 ? 'No habits' : '$count ${count == 1 ? 'habit' : 'habits'}';

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class _CategoryIcon extends StatelessWidget {
  final Category category;

  const _CategoryIcon(this.category);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(color: category.color.withOpacity(0.18), shape: BoxShape.circle),
      child: Icon(category.icon, size: 20, color: category.color),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final Category category;
  final int index;
  final int habitCount;

  const _CategoryRow({Key? key, required this.category, required this.index, required this.habitCount})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      child: ListTile(
        leading: _CategoryIcon(category),
        title: Text(category.name),
        subtitle: Text(_habitCountText(habitCount)),
        onTap: () => showCategoryEditorSheet(context, existing: category),
        trailing: ReorderableDragStartListener(
          index: index,
          child: SizedBox(
            key: Key('dragHandle_${category.id}'),
            width: 44,
            height: 44,
            child: Semantics(
              label: 'Reorder ${category.name}',
              child: Icon(isCupertino(context) ? CupertinoIcons.line_horizontal_3 : Icons.drag_handle),
            ),
          ),
        ),
      ),
    );
  }
}

/// Limit note and the Recently Deleted section, below the reorderable list.
class _Footer extends StatelessWidget {
  final bool atLimit;
  final List<Habit> habits;

  const _Footer({required this.atLimit, required this.habits});

  @override
  Widget build(BuildContext context) {
    final deleted = context.watch<CategoryProvider>().deletedCategories;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (atLimit)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'You can have up to ${Category.maxCount} categories.',
              style: TextStyle(color: secondaryLabel(context)),
            ),
          ),
        if (deleted.isNotEmpty) ...[
          const SectionHeader('Recently Deleted'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Habits in a deleted category are kept and shown as Uncategorized.',
              style: TextStyle(color: secondaryLabel(context)),
            ),
          ),
          for (final category in deleted)
            _DeletedRow(
              key: Key('deletedRow_${category.id}'),
              category: category,
              habitCount: _countHabits(habits, category.id),
            ),
        ],
      ],
    );
  }
}

class _DeletedRow extends StatelessWidget {
  final Category category;
  final int habitCount;

  const _DeletedRow({Key? key, required this.category, required this.habitCount}) : super(key: key);

  Future<void> _restore(BuildContext context) async {
    final provider = context.read<CategoryProvider>();
    final restored = await provider.restore(category.id);
    if (!context.mounted) return;
    if (restored == null) {
      _showMessage(context, provider.error ?? 'Could not restore "${category.name}"');
    } else if (restored.name != category.name) {
      _showMessage(context, 'Restored as "${restored.name}"');
    }
  }

  Future<void> _moveHabits(BuildContext context) async {
    final categoryProvider = context.read<CategoryProvider>();
    final target = await chooseAdaptive<Category>(
      context,
      title: 'Move ${_habitCountText(habitCount).toLowerCase()} to…',
      options: [
        for (final c in categoryProvider.categories) AdaptiveOption(c, c.name, key: Key('moveTarget_${c.id}')),
      ],
    );
    if (target == null || !context.mounted) return;

    final moved = await categoryProvider.moveHabits(category.id, target.id);
    if (!context.mounted) return;
    if (moved == null) {
      _showMessage(context, categoryProvider.error ?? 'Could not move the habits');
      return;
    }
    await context.read<HabitProvider>().loadHabits();
    if (context.mounted) {
      _showMessage(context, 'Moved ${_habitCountText(moved).toLowerCase()} to ${target.name}');
    }
  }

  Future<void> _deletePermanently(BuildContext context) async {
    final confirmed = await confirmAdaptive(
      context,
      title: 'Permanently delete "${category.name}"?',
      message: 'This can\'t be undone.',
      confirmLabel: 'Delete Permanently',
      destructive: true,
      confirmKey: const Key('confirmDeletePermanently'),
    );
    if (!confirmed || !context.mounted) return;

    final provider = context.read<CategoryProvider>();
    if (!await provider.deletePermanently(category.id) && context.mounted) {
      _showMessage(context, provider.error ?? 'Could not delete "${category.name}"');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Opacity(opacity: 0.5, child: _CategoryIcon(category)),
      title: Text(category.name, style: TextStyle(color: secondaryLabel(context))),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(habitCount == 0
              ? 'No habits'
              : '${_habitCountText(habitCount)} · shown as Uncategorized'),
          // Wraps on narrow screens rather than overflowing
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                key: Key('restoreCategory_${category.id}'),
                onPressed: () => _restore(context),
                child: const Text('Restore'),
              ),
              if (habitCount > 0)
                TextButton(
                  key: Key('moveHabits_${category.id}'),
                  onPressed: () => _moveHabits(context),
                  child: const Text('Move habits to…'),
                )
              else
                TextButton(
                  key: Key('deletePermanently_${category.id}'),
                  onPressed: () => _deletePermanently(context),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Delete Permanently'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
