import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../domain/entities/category.dart';
import '../domain/entities/habit.dart';
import '../domain/entities/habit_color.dart';
import '../domain/entities/habit_schedule.dart';
import '../domain/entities/reset_frequency.dart';
import '../domain/entities/reminder_settings.dart';
import '../domain/entities/two_minute_version.dart';
import '../domain/usecases/create_habit_usecase.dart';
import '../domain/usecases/update_habit_usecase.dart';
import '../presentation/providers/theme_provider.dart';
import '../core/locale/week_start.dart';
import '../presentation/providers/category_provider.dart';
import '../presentation/providers/settings_provider.dart';
import '../presentation/providers/habit_provider.dart';
import '../presentation/widgets/category_icons.dart';
import '../presentation/widgets/color_picker.dart';
import '../presentation/widgets/confirm_delete_habit.dart';
import '../presentation/widgets/habit_icons.dart';
import '../presentation/widgets/selectable_swatch.dart';
import '../presentation/widgets/unsaved_changes_guard.dart';
import 'categories_screen.dart';
import '../core/theme/ios_colors.dart';
import '../core/exceptions/friendly_error.dart';
import 'package:flutter/cupertino.dart';
import '../core/theme/app_style.dart';
import '../presentation/widgets/adaptive.dart';
import '../domain/services/reminder_planner.dart';

class AddHabitScreen extends StatefulWidget {
  final Habit? editHabit;
  
  const AddHabitScreen({Key? key, this.editHabit}) : super(key: key);

  @override
  _AddHabitScreenState createState() => _AddHabitScreenState();
}

class _AddHabitScreenState extends State<AddHabitScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _targetController = TextEditingController();
  final TextEditingController _unitsController = TextEditingController();
  // The two-minute version: what it is, and an amount that counts by itself
  final TextEditingController _tinyController = TextEditingController();
  final TextEditingController _tinyMinimumController = TextEditingController();
  bool _tinyShowOnCard = true;
  
  bool _isSubmitting = false;
  
  // Selected values
  HabitColor _selectedColor = HabitColor.blue;
  // An id, so a habit in an unknown/deleted category keeps it unless changed
  String _selectedCategoryId = '';
  ResetFrequency _selectedFrequency = ResetFrequency.daily;
  // Weekly habits reset on this date's weekday, monthly on its day of month
  DateTime _resetAnchor = DateUtils.dateOnly(DateTime.now());
  int _resetInterval = 1;
  // Days a daily habit is due; all seven means every day
  List<int> _scheduleDays = [1, 2, 3, 4, 5, 6, 7];
  // Reminder days mirror the schedule until the user picks them separately
  // Smart reminders follow the schedule (see ReminderPlanner)
  ReminderMode _reminderMode = ReminderMode.smart;
  
  // Reminder settings
  // New habits remind by default, at the time chosen in Settings
  bool _reminderEnabled = true;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 9, minute: 0);
  List<int> _selectedDays = [1, 2, 3, 4, 5, 6, 7]; // All days by default
  String _customMessage = '';
  
  // Icon selection
  String? _selectedIcon;
  
  /// Active categories, plus Uncategorized when editing a habit whose
  /// category was deleted (it's never offered for a new habit).
  List<Category> _categoryChoices(BuildContext context) {
    final provider = context.watch<CategoryProvider>();
    final original = widget.editHabit?.categoryId;
    return [
      ...provider.categories,
      if (original != null && !provider.isActive(original)) Category.uncategorized,
    ];
  }

  Future<void> _deleteFromForm() async {
    final habit = widget.editHabit!;
    if (!await confirmDeleteHabit(context, habit.name) || !mounted) return;

    final habitProvider = context.read<HabitProvider>();
    if (await habitProvider.deleteHabit(habit.id)) {
      // pop (not maybePop): the habit is gone, so no unsaved-changes prompt
      if (mounted) Navigator.of(context).pop();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Couldn't delete \"${habit.name}\". Please try again.")),
      );
    }
  }

  static Widget? _noCounter(BuildContext context,
          {required int currentLength, required bool isFocused, required int? maxLength}) =>
      null;

  void _showSaveError(String? error) {
    final name = _nameController.text.trim();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(friendlyError(
          error,
          fallback: "Couldn't save${name.isEmpty ? ' this habit' : ' "$name"'}. Please try again.",
        )),
      ),
    );
  }

  /// The save button, pinned to the bottom of the screen (a "sticky footer")
  /// so it's reachable without scrolling.
  Widget _buildActionBar(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const Key('habitActionBar'),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: theme.dividerColor, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              key: const Key('saveHabitButton'),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppStyle.controlRadius)),
                textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              onPressed: _isSubmitting ? null : _submitForm,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                    )
                  : Text(widget.editHabit != null ? 'Save Changes' : 'Add Habit'),
            ),
          ),
        ),
      ),
    );
  }

  /// Opens the Categories page on top of the form (so nothing typed is
  /// lost), then picks up what changed there.
  Future<void> _openCategories() async {
    final provider = context.read<CategoryProvider>();
    final before = provider.categories.map((c) => c.id).toSet();

    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CategoriesScreen()));
    if (!mounted) return;

    final categories = provider.categories;
    final added = categories.where((c) => !before.contains(c.id)).toList();
    setState(() {
      if (added.length == 1) {
        // Most likely made for this habit
        _selectedCategoryId = added.single.id;
      } else if (widget.editHabit == null && !provider.isActive(_selectedCategoryId) && categories.isNotEmpty) {
        // The chosen category was deleted while away
        _selectedCategoryId = categories.first.id;
      }
    });
  }

  // Colors other habits use (newest first), then common basics
  List<HabitColor> _colorSuggestions(BuildContext context) {
    final habits = List.of(context.read<HabitProvider>().habits)
      ..sort((a, b) => b.metadata.createdDate.compareTo(a.metadata.createdDate));
    return ColorPalette.suggestions(habits.map((h) => h.color.value));
  }

  // Weekday chips start on the user's first day of the week
  List<int> _weekdaysInOrder(BuildContext context) =>
      weekdaysStartingOn(context.watch<SettingsProvider>().firstDayOfWeek);

  // Which chip shows as selected for a stored id
  String _chipIdFor(String categoryId) =>
      context.read<CategoryProvider>().isActive(categoryId) ? categoryId : Category.uncategorizedId;

  // Apple's Human Interface Guidelines: tap targets at least 44x44 pt
  static const double _swatchSpacing = 12;
  static const double _chipSpacing = 8;
  static const int _maxInterval = 30;
  static const _weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  HabitSchedule get _schedule => HabitSchedule(
        frequency: _selectedFrequency,
        interval: _resetInterval,
        anchor: _resetAnchor,
        weekdays: _scheduleDays,
      );

  // The start date only matters when periods don't simply follow the calendar day
  bool get _startDateMatters =>
      _selectedFrequency.isPeriodic &&
      (_selectedFrequency != ResetFrequency.daily || _resetInterval > 1);


  @override
  void initState() {
    super.initState();
    final categories = context.read<CategoryProvider>().categories;
    if (categories.isNotEmpty) _selectedCategoryId = categories.first.id;
    _reminderTime = context.read<SettingsProvider>().defaultReminderTime;
    
    // If editing an existing habit, populate the form
    if (widget.editHabit != null) {
      final habit = widget.editHabit!;
      _nameController.text = habit.name;
      _targetController.text = habit.target.toString();
      _unitsController.text = habit.units;
      _selectedColor = habit.color;
      _selectedCategoryId = habit.categoryId;
      _selectedFrequency = habit.resetFrequency;
      _resetAnchor = habit.resetAnchor;
      _resetInterval = habit.resetInterval;
      _scheduleDays = List.of(habit.scheduledWeekdays ?? const [1, 2, 3, 4, 5, 6, 7]);
      // Initialize reminder settings
      final reminder = habit.reminder;
      _reminderEnabled = reminder?.enabled ?? false;
      if (reminder != null) {
        _reminderMode = reminder.mode;
        _reminderTime = reminder.time;
        _selectedDays = List.from(reminder.daysOfWeek);
        _customMessage = reminder.customMessage ?? '';
      }
      
      // Initialize icon
      _selectedIcon = habit.metadata.icon;

      final tiny = habit.twoMinute;
      if (tiny != null) {
        _tinyController.text = tiny.description;
        _tinyMinimumController.text = tiny.minimum?.toString() ?? '';
        _tinyShowOnCard = tiny.showOnCard;
      }
      
    }

    // Unsaved-changes check: compare against the form as it opened
    _initialSnapshot = _formSnapshot();
    for (final controller in _textControllers) {
      controller.addListener(_onTextChanged);
    }
  }

  late final String _initialSnapshot;

  List<TextEditingController> get _textControllers =>
      [_nameController, _targetController, _unitsController, _tinyController, _tinyMinimumController];

  int? get _enteredTarget => int.tryParse(_targetController.text.trim());

  // A minimum only makes sense when the target is more than one
  bool get _tinyMinimumApplies => (_enteredTarget ?? 0) > 1;

  /// The two-minute version the form would save, or null for none. Habits
  /// that never reset have no streak to keep, so they don't get one.
  TwoMinuteVersion? get _twoMinute {
    final description = _tinyController.text.trim();
    if (description.isEmpty || !_selectedFrequency.isPeriodic) return null;
    return TwoMinuteVersion(
      description: description,
      minimum: _tinyMinimumApplies ? int.tryParse(_tinyMinimumController.text.trim()) : null,
      showOnCard: _tinyShowOnCard,
    );
  }

  // Rebuild so the leave-confirmation knows about typed changes
  void _onTextChanged() => setState(() {});

  bool get _hasUnsavedChanges => _formSnapshot() != _initialSnapshot;

  /// Every value the form would save, as one comparable string.
  String _formSnapshot() => jsonEncode([
        _nameController.text,
        _targetController.text,
        _unitsController.text,
        _selectedColor.value,
        _selectedCategoryId,
        _selectedFrequency.name,
        _resetInterval,
        _resetAnchor.toIso8601String(),
        _scheduleDays,
        _reminderEnabled,
        _reminderMode.name,
        _reminderTime.hour * 60 + _reminderTime.minute,
        _selectedDays,
        _customMessage,
        _selectedIcon,
        _tinyController.text.trim(),
        _tinyMinimumController.text.trim(),
        _tinyShowOnCard,
      ]);

  @override
  void dispose() {
    for (final controller in _textControllers) {
      controller.removeListener(_onTextChanged);
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      // Rebuilds when the appearance changes
      builder: (context, themeProvider, child) {
        return UnsavedChangesGuard(
          hasChanges: _hasUnsavedChanges,
          child: Scaffold(
      appBar: isCupertino(context)
          ? CupertinoNavigationBar(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              middle: Text(widget.editHabit != null ? 'Edit Habit' : 'New Habit'),
              // maybePop, so unsaved changes are confirmed first
              leading: CupertinoButton(
                key: const Key('cancelHabitForm'),
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Cancel'),
              ),
            )
          : AppBar(
              title: Text(widget.editHabit != null ? 'Edit Habit' : 'New Habit'),
              centerTitle: true,
            ) as PreferredSizeWidget,
      body: Column(children: [
        Expanded(child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Habit Name Field
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Habit Name',
                  hintText: 'e.g. Drink water',
                  errorMaxLines: 2,
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a habit name';
                  }
                  if (value.trim().length < 2) {
                    return 'Habit name must be at least 2 characters';
                  }
                  if (value.trim().length > 50) {
                    return 'Habit name cannot exceed 50 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Target Field
              TextFormField(
                controller: _targetController,
                decoration: InputDecoration(
                  labelText: 'Target Number',
                  hintText: 'e.g. 8',
                  errorMaxLines: 2,
                  border: const OutlineInputBorder(),
                  // Makes "3 per week" style goals explicit
                  suffixText: _schedule.periodLabel,
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a target number';
                  }
                  final target = int.tryParse(value.trim());
                  if (target == null || target <= 0) {
                    return 'Target must be a positive number';
                  }
                  if (target > 1000) {
                    return 'Target cannot exceed 1000';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Units Field
              TextFormField(
                controller: _unitsController,
                decoration: const InputDecoration(
                  labelText: 'Units (Optional)',
                  hintText: 'e.g. glasses',
                  errorMaxLines: 2,
                  border: OutlineInputBorder(),
                ),
                maxLength: 20,
                // Enforce the limit without Material's "0/20" counter
                buildCounter: _noCounter,
                validator: (value) {
                  if (value != null && value.trim().length > 20) {
                    return 'Units cannot exceed 20 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              
              // Category Selection
              const SectionHeader('Category', padding: EdgeInsets.only(left: 4, bottom: 4)),
              const SizedBox(height: 8),
              Wrap(
                spacing: _chipSpacing,
                runSpacing: _chipSpacing,
                children: _categoryChoices(context).map((category) {
                  final isSelected = _chipIdFor(_selectedCategoryId) == category.id;
                  return FilterChip(
                    key: Key('categoryChip_${category.id == Category.uncategorizedId ? 'uncategorized' : category.id}'),
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(category.icon, size: 16, color: category.color),
                        const SizedBox(width: 4),
                        Text(category.name),
                      ],
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        // Choosing Uncategorized again keeps the habit's original id,
                        // so restoring its category brings it back
                        _selectedCategoryId = category.id == Category.uncategorizedId
                            ? widget.editHabit!.categoryId
                            : category.id;
                      });
                    },
                    backgroundColor: isSelected ? category.color.withOpacity(0.2) : null,
                  );
                }).toList(),
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  key: const Key('manageCategories'),
                  onPressed: _openCategories,
                  child: const Text('Manage Categories'),
                ),
              ),
              const SizedBox(height: 24),
              
              // Color Selection
              const SectionHeader('Color', padding: EdgeInsets.only(left: 4, bottom: 4)),
              const SizedBox(height: 8),
              CompactColorPicker(
                selectedValue: _selectedColor.value,
                onChanged: (color) => setState(() => _selectedColor = color),
                suggestions: _colorSuggestions(context),
              ),
              const SizedBox(height: 24),
              
              // Icon Selection
              const SectionHeader('Icon', padding: EdgeInsets.only(left: 4, bottom: 4)),
              const SizedBox(height: 8),
              Wrap(
                spacing: _swatchSpacing,
                runSpacing: _swatchSpacing,
                children: [
                  SelectableSwatch(
                    key: const Key('iconSwatch_none'),
                    semanticLabel: 'No icon',
                    isSelected: _selectedIcon == null,
                    onTap: () => setState(() => _selectedIcon = null),
                    fill: CupertinoDynamicColor.resolve(IOSColors.tertiarySystemFill, context),
                    borderColor: _selectedIcon == null ? Theme.of(context).primaryColor : null,
                    borderWidth: 3,
                    child: Icon(
                      Icons.close,
                      color: secondaryLabel(context),
                      size: 22,
                    ),
                  ),
                  ...HabitIcons.library.entries.map((entry) {
                    final iconKey = entry.key;
                    final isSelected = _selectedIcon == iconKey;
                    return SelectableSwatch(
                      key: Key('iconSwatch_$iconKey'),
                      semanticLabel: '$iconKey icon',
                      isSelected: isSelected,
                      onTap: () => setState(() => _selectedIcon = iconKey),
                      fill: isSelected
                          ? _selectedColor.color.withOpacity(0.2)
                          : CupertinoDynamicColor.resolve(IOSColors.secondarySystemFill, context),
                      borderColor: isSelected ? _selectedColor.color : null,
                      borderWidth: 2,
                      child: Icon(
                        entry.value,
                        color: isSelected
                            ? _selectedColor.color
                            : secondaryLabel(context),
                        size: 22,
                      ),
                    );
                  }).toList(),
                ],
              ),
              const SizedBox(height: 24),
              
              // Schedule
              const SectionHeader('Schedule', padding: EdgeInsets.only(left: 4, bottom: 4)),
              const SizedBox(height: 8),
              Wrap(
                spacing: _chipSpacing,
                runSpacing: _chipSpacing,
                children: [
                  for (final frequency in ResetFrequency.values)
                    ChoiceChip(
                      key: Key('frequency_${frequency.name}'),
                      avatar: Icon(_getFrequencyIcon(frequency), size: 18),
                      label: Text(frequency.displayName),
                      selected: _selectedFrequency == frequency,
                      onSelected: (_) => setState(() => _selectedFrequency = frequency),
                    ),
                ],
              ),
              if (_selectedFrequency.isPeriodic) ...[
                const SizedBox(height: 8),
                // Wraps at large text sizes rather than overflowing
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('Every', style: TextStyle(fontSize: 16)),
                    IconButton(
                      key: const Key('intervalMinus'),
                      icon: const Icon(Icons.remove_circle_outline),
                      tooltip: 'Decrease interval',
                      onPressed: _resetInterval > 1 ? () => setState(() => _resetInterval--) : null,
                    ),
                    Text(
                      '$_resetInterval',
                      key: const Key('intervalValue'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    IconButton(
                      key: const Key('intervalPlus'),
                      icon: const Icon(Icons.add_circle_outline),
                      tooltip: 'Increase interval',
                      onPressed: _resetInterval < _maxInterval ? () => setState(() => _resetInterval++) : null,
                    ),
                    Text(
                      '${_selectedFrequency.periodUnit}${_resetInterval == 1 ? '' : 's'}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ],
              if (_selectedFrequency == ResetFrequency.daily && _resetInterval == 1) ...[
                const SizedBox(height: 4),
                const Text('Due on', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [for (final day in _weekdaysInOrder(context)) _buildScheduleDayChip(day)],
                ),
              ],
              ListTile(
                key: const Key('scheduleSummary'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_repeat),
                title: Text(_schedule.describe()),
                trailing: _startDateMatters
                    ? TextButton(
                        key: const Key('changeStartDate'),
                        onPressed: _pickResetDay,
                        child: const Text('Change'),
                      )
                    : null,
                onTap: _startDateMatters ? _pickResetDay : null,
              ),
              const SizedBox(height: 24),

              if (_selectedFrequency.isPeriodic) ...[
                _buildTwoMinuteSection(context),
                const SizedBox(height: 24),
              ],

              // Reminder Settings Section
              const SectionHeader('Reminder', padding: EdgeInsets.only(left: 4, bottom: 4)),
              const SizedBox(height: 8),
              
              // Enable Reminder Switch
              // The label is part of the switch: tappable, and read with it by VoiceOver
              SwitchListTile.adaptive(
                key: const Key('reminderSwitch'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Remind me about this habit'),
                value: _reminderEnabled,
                onChanged: (value) => setState(() => _reminderEnabled = value),
              ),
              
              if (_reminderEnabled) ...[
                const SizedBox(height: 16),
                
                // Time Picker
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Reminder time: ${_reminderTime.format(context)}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    TextButton(
                      key: const Key('changeReminderTime'),
                      onPressed: () async {
                        final time = await pickTimeAdaptive(context, initial: _reminderTime);
                        if (time != null) {
                          setState(() {
                            _reminderTime = time;
                          });
                        }
                      },
                      child: const Text('Change Time'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildReminderModeControl(),
                const SizedBox(height: 12),
                if (_reminderMode == ReminderMode.smart)
                  Text(
                    "${ReminderPlanner.describeSmart(_schedule)}. Skipped once you're done.",
                    key: const Key('reminderSummary'),
                    style: TextStyle(fontSize: 14, color: secondaryLabel(context)),
                  )
                else
                  Wrap(
                    spacing: _chipSpacing,
                    runSpacing: _chipSpacing,
                    children: [
                      for (final day in _weekdaysInOrder(context)) _buildDayChip(day, _weekdayShort[day - 1]),
                    ],
                  ),
                const SizedBox(height: 16),

                // Custom Message (Optional)
                TextFormField(
                  initialValue: _customMessage,
                  decoration: const InputDecoration(
                    labelText: 'Message (optional)',
                    hintText: 'e.g. Time for a walk!',
                    border: OutlineInputBorder(),
                  ),
                  maxLength: 100,
                  buildCounter: _noCounter,
                  onChanged: (value) {
                    setState(() => _customMessage = value);
                  },
                ),
              ],
              // Another way to delete, besides swiping the habit card
              if (widget.editHabit != null) ...[
                const SizedBox(height: 32),
                Center(
                  child: TextButton.icon(
                    key: const Key('deleteHabitFromForm'),
                    onPressed: _isSubmitting ? null : _deleteFromForm,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete Habit'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                      minimumSize: const Size(44, 44),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        )),
        // Pinned below the scrolling form; rides above the keyboard
        _buildActionBar(context),
      ]),
          ),
        );
      },
    );
  }

  /// The tiny version for hard days ("Put on running shoes"), an optional
  /// amount that counts by itself, and whether the card shows "2 min".
  Widget _buildTwoMinuteSection(BuildContext context) {
    final hasTiny = _tinyController.text.trim().isNotEmpty;
    final units = _unitsController.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Two-minute version', padding: EdgeInsets.only(left: 4, bottom: 4)),
        const SizedBox(height: 8),
        TextFormField(
          key: const Key('twoMinuteField'),
          controller: _tinyController,
          decoration: const InputDecoration(
            labelText: 'Tiny version (optional)',
            hintText: 'e.g. Put on running shoes',
            errorMaxLines: 2,
            border: OutlineInputBorder(),
          ),
          maxLength: TwoMinuteVersion.maxLength,
          buildCounter: _noCounter,
          textCapitalization: TextCapitalization.sentences,
        ),
        if (hasTiny && _tinyMinimumApplies) ...[
          const SizedBox(height: 16),
          TextFormField(
            key: const Key('twoMinuteMinimum'),
            controller: _tinyMinimumController,
            decoration: InputDecoration(
              labelText: 'Minimum (optional)',
              hintText: 'e.g. 1',
              helperText: 'Logging this much counts too',
              helperMaxLines: 2,
              errorMaxLines: 2,
              border: const OutlineInputBorder(),
              suffixText: units.isEmpty ? null : units,
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.isEmpty) return null;
              final minimum = int.tryParse(text);
              final target = _enteredTarget ?? 0;
              if (minimum == null || minimum < 1 || minimum >= target) {
                return 'Enter a number from 1 to ${target - 1}';
              }
              return null;
            },
          ),
        ],
        if (hasTiny)
          SwitchListTile.adaptive(
            key: const Key('twoMinuteOnCard'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Show on card'),
            value: _tinyShowOnCard,
            onChanged: (value) => setState(() => _tinyShowOnCard = value),
          ),
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 6),
          child: Text(
            'On a hard day, do just this. It keeps your streak and counts half toward momentum.',
            style: TextStyle(fontSize: 13, color: secondaryLabel(context)),
          ),
        ),
      ],
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final habitProvider = context.read<HabitProvider>();
      
      // Store initial habit count to detect if habit was actually added
      
      // Build reminder settings. When editing a habit that had a reminder,
      // turning it off must send a disabled reminder: null means "unchanged"
      // to updateDetails, which would leave the old reminder firing.
      final reminderOn =
          _reminderEnabled && (_reminderMode == ReminderMode.smart || _selectedDays.isNotEmpty);
      ReminderSettings? reminder;
      if (reminderOn || widget.editHabit?.reminder != null) {
        reminder = ReminderSettings(
          time: _reminderTime,
          enabled: reminderOn,
          mode: _reminderMode,
          daysOfWeek: List.from(_selectedDays),
          customMessage: _customMessage.isNotEmpty ? _customMessage : null,
        );
      }
      
      final params = CreateHabitParams(
        name: _nameController.text.trim(),
        target: int.parse(_targetController.text.trim()),
        units: _unitsController.text.trim(),
        color: _selectedColor,
        categoryId: _selectedCategoryId,
        resetFrequency: _selectedFrequency,
        reminder: reminder,
        icon: _selectedIcon,
        resetAnchor: _resetAnchor,
        resetInterval: _selectedFrequency.isPeriodic ? _resetInterval : 1,
        scheduledWeekdays: List.of(_scheduleDays),
        twoMinute: _twoMinute,
      );

      final bool success;
      if (widget.editHabit != null) {
        // Update existing habit
        success = await habitProvider.updateHabitDetails(widget.editHabit!.id, UpdateHabitParams(
          name: params.name,
          target: params.target,
          units: params.units,
          color: params.color,
          categoryId: params.categoryId,
          resetFrequency: params.resetFrequency,
          reminder: reminder,
          // '' tells updateDetails to remove an existing icon ("No icon")
          icon: _selectedIcon ?? '',
          resetAnchor: _resetAnchor,
          resetInterval: params.resetInterval,
          // All seven days means "every day", which also clears a weekday schedule
          scheduledWeekdays: params.scheduledWeekdays,
          twoMinute: params.twoMinute,
          removeTwoMinute: params.twoMinute == null && widget.editHabit!.twoMinute != null,
        ));
      } else {
        success = await habitProvider.createHabit(params);
      }
      
      if (!mounted) return;
      if (success) {
        // pop (not maybePop): the changes are saved, so no unsaved-changes prompt
        Navigator.of(context).pop();
      } else {
        // Stay on the form so nothing typed is lost
        _showSaveError(habitProvider.error);
      }
    } catch (e) {
      if (mounted) _showSaveError(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _pickResetDay() async {
    final picked = await pickDateAdaptive(
      context,
      initial: _resetAnchor,
      first: _resetAnchor.isBefore(DateTime(2020)) ? _resetAnchor : DateTime(2020),
      last: DateTime.now().add(const Duration(days: 366)),
      helpText: _selectedFrequency == ResetFrequency.weekly
          ? 'Resets on this weekday'
          : _selectedFrequency == ResetFrequency.monthly
              ? 'Resets on this day each month'
              : 'Start date',
    );
    if (picked != null) {
      setState(() {
        _resetAnchor = DateUtils.dateOnly(picked);
      });
    }
  }

  IconData _getFrequencyIcon(ResetFrequency frequency) {
    switch (frequency) {
      case ResetFrequency.daily:
        return Icons.today;
      case ResetFrequency.weekly:
        return Icons.view_week;
      case ResetFrequency.monthly:
        return Icons.calendar_month;
      case ResetFrequency.never:
        return Icons.all_inclusive;
    }
  }
  
  Widget _buildScheduleDayChip(int day) {
    final isSelected = _scheduleDays.contains(day);
    return FilterChip(
      key: Key('scheduleDay_$day'),
      label: Text(_weekdayShort[day - 1]),
      selected: isSelected,
      onSelected: (selected) {
        // At least one day must stay selected
        if (!selected && _scheduleDays.length == 1) return;
        setState(() {
          if (selected) {
            _scheduleDays.add(day);
          } else {
            _scheduleDays.remove(day);
          }
          _scheduleDays.sort();
        });
      },
    );
  }

  /// Smart (follows the schedule) or Custom days.
  Widget _buildReminderModeControl() {
    const labels = {ReminderMode.smart: 'Smart', ReminderMode.custom: 'Custom days'};
    void choose(ReminderMode? mode) {
      if (mode != null) setState(() => _reminderMode = mode);
    }

    if (isCupertino(context)) {
      return SizedBox(
        width: double.infinity,
        child: CupertinoSlidingSegmentedControl<ReminderMode>(
          key: const Key('reminderMode'),
          groupValue: _reminderMode,
          onValueChanged: choose,
          children: {for (final e in labels.entries) e.key: Text(e.value)},
        ),
      );
    }
    return SegmentedButton<ReminderMode>(
      key: const Key('reminderMode'),
      segments: [for (final e in labels.entries) ButtonSegment(value: e.key, label: Text(e.value))],
      selected: {_reminderMode},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => choose(selection.first),
    );
  }

  Widget _buildDayChip(int dayOfWeek, String label) {
    final isSelected = _selectedDays.contains(dayOfWeek);
    return FilterChip(
      key: Key('reminderDay_$dayOfWeek'),
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _selectedDays.add(dayOfWeek);
          } else {
            _selectedDays.remove(dayOfWeek);
          }
        });
      },
    );
  }
}