import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/validation/category_validator.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/habit_color.dart';
import '../providers/category_provider.dart';
import '../providers/habit_provider.dart';
import 'category_icons.dart';
import 'color_picker.dart';
import 'selectable_swatch.dart';
import 'unsaved_changes_guard.dart';
import 'adaptive.dart';
import 'package:flutter/cupertino.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_style.dart';

/// Add a category, or edit [existing] (including deleting it).
Future<void> showCategoryEditorSheet(BuildContext context, {Category? existing}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // A drag closes the sheet without asking about unsaved changes; Cancel
    // and tapping outside do ask
    enableDrag: false,
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

  bool get _hasUnsavedChanges {
    final existing = widget.existing;
    return _name.text.trim() != (existing?.name ?? '') ||
        _colorValue != (existing?.colorValue ?? HabitColor.blue.value) ||
        _iconKey != (existing?.iconKey ?? 'star');
  }

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

    final confirmed = await confirmAdaptive(
      context,
      title: 'Delete "${category.name}"?',
      message: '${habitsText}You can restore it from Recently Deleted.',
      confirmLabel: 'Delete',
      destructive: true,
      confirmKey: const Key('confirmDeleteCategory'),
    );
    if (!confirmed || !mounted) return;

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
    final palette = AppPalette.of(context);
    final color = palette.habitColor(Color(_colorValue));
    final canDelete = provider.categories.length > 1;

    return UnsavedChangesGuard(
      hasChanges: _hasUnsavedChanges,
      child: Padding(
      // Keep the name field above the keyboard
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title centered between Cancel and an invisible copy of it, so it
            // stays centered however wide Cancel is, and wraps if it must
            Row(
              children: [
                TextButton(
                  key: const Key('cancelCategoryEdit'),
                  // maybePop, so unsaved changes are confirmed first
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Cancel'),
                ),
                Expanded(
                  child: Text(
                    _isNew ? 'New Category' : 'Edit Category',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
                ExcludeSemantics(
                  child: IgnorePointer(
                    child: Opacity(opacity: 0, child: TextButton(onPressed: () {}, child: const Text('Cancel'))),
                  ),
                ),
              ],
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
                errorMaxLines: 2,
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
            CompactColorPicker(
              keyPrefix: 'categoryColorSwatch_',
              selectedValue: _colorValue,
              onChanged: (habitColor) => setState(() => _colorValue = habitColor.value),
              // Other categories' colors first, then common basics
              suggestions: ColorPalette.suggestions(
                provider.categories.where((c) => c.id != widget.existing?.id).map((c) => c.colorValue),
              ),
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
                    fill: entry.key == _iconKey ? color.withOpacity(0.2) : palette.raised,
                    borderColor: entry.key == _iconKey ? color : null,
                    borderWidth: 2,
                    child: Icon(entry.value, size: 22, color: entry.key == _iconKey ? color : secondaryLabel(context)),
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
                style: TextButton.styleFrom(foregroundColor: palette.danger),
                child: const Text('Delete Category'),
              ),
              if (!canDelete)
                Text(
                  'Keep at least one category',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: secondaryLabel(context)),
                ),
            ],
          ],
        ),
      ),
      ),
    );
  }
}
