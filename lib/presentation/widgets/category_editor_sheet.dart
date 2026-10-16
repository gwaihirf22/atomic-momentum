import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/validation/category_validator.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/habit_color.dart';
import '../providers/category_provider.dart';
import '../providers/habit_provider.dart';
import 'category_icons.dart';
import 'selectable_swatch.dart';

/// Add a category, or edit [existing] (including deleting it).
Future<void> showCategoryEditorSheet(BuildContext context, {Category? existing}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _CategoryEditor(existing: existing),
  );
}

class _CategoryEditor extends StatefulWidget {
  final Category? existing;

  const _CategoryEditor({this.existing});

  @override
  State<_CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<_CategoryEditor> {
  static const _swatchSpacing = 12.0;

  late final TextEditingController _name;
  late int _colorValue;
  late String _iconKey;
  bool _nameEdited = false;
  bool _saving = false;
  String? _saveError;

  bool get _isNew => widget.existing == null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _name = TextEditingController(text: existing?.name ?? '');
    _colorValue = existing?.colorValue ?? HabitColor.blue.value;
    _iconKey = existing?.iconKey ?? 'star';
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final provider = context.read<CategoryProvider>();
    setState(() => _saving = true);
    final ok = _isNew
        ? await provider.add(name: _name.text, iconKey: _iconKey, colorValue: _colorValue)
        : await provider.update(widget.existing!.copyWith(name: _name.text, iconKey: _iconKey, colorValue: _colorValue));
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _saving = false;
        _saveError = provider.error;
      });
    }
  }

  Future<void> _delete() async {
    final category = widget.existing!;
    final habitCount = context.read<HabitProvider>().habits.where((h) => h.categoryId == category.id).length;
    final habitsText = habitCount == 0
        ? ''
        : 'Its $habitCount ${habitCount == 1 ? 'habit' : 'habits'} and their streaks are kept '
            'and shown as Uncategorized. ';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${category.name}"?'),
        content: Text('${habitsText}You can restore it from Recently Deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            key: const Key('confirmDeleteCategory'),
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final provider = context.read<CategoryProvider>();
    if (await provider.delete(category.id)) {
      if (mounted) Navigator.of(context).pop();
    } else if (mounted) {
      setState(() => _saveError = provider.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CategoryProvider>();
    final nameError =
        CategoryValidator.validateName(_name.text, provider.categories, excludeId: widget.existing?.id);
    final color = Color(_colorValue);
    final canDelete = provider.categories.length > 1;

    return Padding(
      // Keep the name field above the keyboard
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isNew ? 'New Category' : 'Edit Category',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // Live preview
            Center(
              child: Chip(
                key: const Key('categoryPreview'),
                avatar: Icon(CategoryIcons.of(_iconKey), size: 18, color: color),
                label: Text(_name.text.trim().isEmpty ? 'Category' : _name.text.trim()),
                backgroundColor: color.withOpacity(0.15),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('categoryNameField'),
              controller: _name,
              maxLength: Category.maxNameLength,
              textCapitalization: TextCapitalization.words,
              autofocus: _isNew,
              decoration: InputDecoration(
                labelText: 'Name',
                border: const OutlineInputBorder(),
                // Don't complain about an empty name before the user has typed
                errorText: (_nameEdited || !_isNew) ? (nameError ?? _saveError) : _saveError,
              ),
              onChanged: (_) => setState(() {
                _nameEdited = true;
                _saveError = null;
              }),
            ),
            const SizedBox(height: 8),
            const Text('Color', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: _swatchSpacing,
              runSpacing: _swatchSpacing,
              children: [
                for (final habitColor in HabitColor.predefinedColors)
                  SelectableSwatch(
                    key: Key('categoryColorSwatch_${habitColor.name}'),
                    semanticLabel: '${habitColor.name} color',
                    isSelected: habitColor.value == _colorValue,
                    onTap: () => setState(() => _colorValue = habitColor.value),
                    fill: habitColor.color,
                    borderColor: habitColor.value == _colorValue ? Theme.of(context).colorScheme.onSurface : null,
                    borderWidth: 3,
                    child: habitColor.value == _colorValue
                        ? const Icon(Icons.check, color: Colors.white, size: 22)
                        : null,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Icon', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: _swatchSpacing,
              runSpacing: _swatchSpacing,
              children: [
                for (final entry in CategoryIcons.library.entries)
                  SelectableSwatch(
                    key: Key('categoryIconSwatch_${entry.key}'),
                    semanticLabel: '${CategoryIcons.label(entry.key)} icon',
                    isSelected: entry.key == _iconKey,
                    onTap: () => setState(() => _iconKey = entry.key),
                    fill: entry.key == _iconKey ? color.withOpacity(0.2) : Colors.grey.withOpacity(0.12),
                    borderColor: entry.key == _iconKey ? color : null,
                    borderWidth: 2,
                    child: Icon(entry.value, size: 22, color: entry.key == _iconKey ? color : Colors.grey.shade600),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              key: const Key('saveCategory'),
              onPressed: nameError == null && !_saving ? _save : null,
              child: Text(_isNew ? 'Add Category' : 'Save'),
            ),
            if (!_isNew) ...[
              const SizedBox(height: 8),
              TextButton(
                key: const Key('deleteCategory'),
                onPressed: canDelete ? _delete : null,
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete Category'),
              ),
              if (!canDelete)
                const Text(
                  'Keep at least one category',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
