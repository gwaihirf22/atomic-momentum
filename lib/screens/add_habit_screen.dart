import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../domain/entities/category.dart';
import '../domain/entities/habit.dart';
import '../domain/entities/habit_color.dart';
import '../domain/entities/habit_schedule.dart';
import '../domain/entities/reset_frequency.dart';
import '../domain/entities/reminder_settings.dart';
import '../domain/usecases/create_habit_usecase.dart';
import '../domain/usecases/update_habit_usecase.dart';
import '../presentation/providers/theme_provider.dart';
import '../core/locale/week_start.dart';
import '../presentation/providers/category_provider.dart';
import '../presentation/providers/settings_provider.dart';
import '../presentation/providers/habit_provider.dart';
import '../presentation/widgets/category_icons.dart';
import '../presentation/widgets/color_picker.dart';
import '../presentation/widgets/habit_icons.dart';
import '../presentation/widgets/selectable_swatch.dart';
import '../presentation/widgets/unsaved_changes_guard.dart';
import 'categories_screen.dart';
import '../core/theme/ios_colors.dart';

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
  bool _reminderDaysFollowSchedule = true;
  
  // Reminder settings
  bool _reminderEnabled = false;
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
            child: ElevatedButton(
              key: const Key('saveHabitButton'),
              onPressed: _isSubmitting ? null : _submitForm,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(widget.editHabit != null ? 'Update Habit' : 'Add Habit'),
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
      _reminderDaysFollowSchedule = habit.reminder == null;
      
      // Initialize reminder settings
      if (habit.reminder != null) {
        _reminderEnabled = habit.reminder!.enabled;
        _reminderTime = habit.reminder!.time;
        _selectedDays = List.from(habit.reminder!.daysOfWeek);
        _customMessage = habit.reminder!.customMessage ?? '';
      }
      
      // Initialize icon
      _selectedIcon = habit.metadata.icon;
      
      print('DEBUG: Initialized edit form for habit: ${habit.name}');
    }

    // Unsaved-changes check: compare against the form as it opened
    _initialSnapshot = _formSnapshot();
    for (final controller in [_nameController, _targetController, _unitsController]) {
      controller.addListener(_onTextChanged);
    }
  }

  late final String _initialSnapshot;

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
        _reminderTime.hour * 60 + _reminderTime.minute,
        _selectedDays,
        _customMessage,
        _selectedIcon,
      ]);

  @override
  void dispose() {
    for (final controller in [_nameController, _targetController, _unitsController]) {
      controller.removeListener(_onTextChanged);
    }
    _nameController.dispose();
    _targetController.dispose();
    _unitsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.themeMode == ThemeMode.dark ||
            (themeProvider.themeMode == ThemeMode.system &&
                MediaQuery.platformBrightnessOf(context) == Brightness.dark);
                
        return UnsavedChangesGuard(
          hasChanges: _hasUnsavedChanges,
          child: Scaffold(
      appBar: AppBar(
        title: Text(widget.editHabit != null ? 'Edit Habit' : 'Add New Habit'),
        centerTitle: true,
      ),
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
                  hintText: 'e.g., Drink Water, Exercise, Read',
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
                  hintText: 'e.g., 8, 30, 5',
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
                  hintText: 'e.g., glasses, minutes, reps, pages',
                  border: OutlineInputBorder(),
                ),
                maxLength: 20,
                validator: (value) {
                  if (value != null && value.trim().length > 20) {
                    return 'Units cannot exceed 20 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              
              // Category Selection
              const Text(
                'Category',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Add or change categories in Settings → Categories',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ),
                  TextButton(
                    key: const Key('manageCategories'),
                    onPressed: _openCategories,
                    child: const Text('Manage'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Color Selection
              const Text(
                'Color',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              CompactColorPicker(
                selectedValue: _selectedColor.value,
                onChanged: (color) => setState(() => _selectedColor = color),
                suggestions: _colorSuggestions(context),
              ),
              const SizedBox(height: 24),
              
              // Icon Selection
              const Text(
                'Icon (Optional)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
                    fill: isDark ? IOSColors.tertiarySystemFill : Colors.grey.shade200,
                    borderColor: _selectedIcon == null ? Theme.of(context).primaryColor : null,
                    borderWidth: 3,
                    child: Icon(
                      Icons.close,
                      color: isDark ? IOSColors.labelDark : Colors.grey,
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
                          : (isDark ? IOSColors.secondarySystemFill : Colors.grey.shade100),
                      borderColor: isSelected ? _selectedColor.color : null,
                      borderWidth: 2,
                      child: Icon(
                        entry.value,
                        color: isSelected
                            ? _selectedColor.color
                            : (isDark ? IOSColors.labelDark : Colors.grey.shade600),
                        size: 22,
                      ),
                    );
                  }).toList(),
                ],
              ),
              const SizedBox(height: 24),
              
              // Schedule
              const Text(
                'Schedule',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
                Row(
                  children: [
                    const Text('Every', style: TextStyle(fontSize: 16)),
                    IconButton(
                      key: const Key('intervalMinus'),
                      icon: const Icon(Icons.remove_circle_outline),
                      tooltip: 'Fewer',
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
                      tooltip: 'More',
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
              
              // Reminder Settings Section
              const Text(
                'Reminder Settings',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              
              // Enable Reminder Switch
              Row(
                children: [
                  Switch(
                    key: const Key('reminderSwitch'),
                    value: _reminderEnabled,
                    onChanged: (value) {
                      setState(() {
                        _reminderEnabled = value;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  // Expanded so the label wraps on narrow screens / large text
                  const Expanded(
                    child: Text(
                      'Enable reminders for this habit',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
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
                    ElevatedButton(
                      onPressed: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: _reminderTime,
                        );
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
                const SizedBox(height: 16),
                
                // Days of Week Selection
                const Text('Days to remind:', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
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
                    labelText: 'Custom reminder message (optional)',
                    hintText: 'e.g., "Time for your daily walk!"',
                    border: OutlineInputBorder(),
                  ),
                  maxLength: 100,
                  onChanged: (value) {
                    setState(() => _customMessage = value);
                  },
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
      final initialHabitCount = habitProvider.habits.length;
      
      // Build reminder settings. When editing a habit that had a reminder,
      // turning it off must send a disabled reminder: null means "unchanged"
      // to updateDetails, which would leave the old reminder firing.
      final reminderOn = _reminderEnabled && _selectedDays.isNotEmpty;
      ReminderSettings? reminder;
      if (reminderOn || widget.editHabit?.reminder != null) {
        reminder = ReminderSettings(
          time: _reminderTime,
          enabled: reminderOn,
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
      );

      final bool success;
      if (widget.editHabit != null) {
        // Update existing habit
        print('DEBUG: Updating existing habit: ${widget.editHabit!.name} -> ${params.name}');
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
        ));
        print('DEBUG: Habit update result: $success');
      } else {
        // Create new habit
        print('DEBUG: Creating habit with params: ${params.name}, target: ${params.target}, units: "${params.units}"');
        print('DEBUG: Initial habit count: $initialHabitCount');
        print('DEBUG: About to call habitProvider.createHabit');
        
        success = await habitProvider.createHabit(params);
        final finalHabitCount = habitProvider.habits.length;
        final habitWasAdded = finalHabitCount > initialHabitCount;
        
        print('DEBUG: Habit creation result: $success');
        print('DEBUG: Final habit count: $finalHabitCount');
        print('DEBUG: Habit was actually added: $habitWasAdded');
      }
      
      print('DEBUG: HabitProvider error: ${habitProvider.error}');
      print('DEBUG: mounted: $mounted');

      // FORCE NAVIGATION - Simple approach without complex conditions
      if (mounted) {
        print('DEBUG: Forcing navigation back to home screen');
        
        // Clear form first
        _nameController.clear();
        _targetController.clear();
        _unitsController.clear();
        _selectedColor = HabitColor.blue;
        final categories = context.read<CategoryProvider>().categories;
        _selectedCategoryId = categories.isEmpty ? '' : categories.first.id;
        _selectedFrequency = ResetFrequency.daily;
        _resetInterval = 1;
        _scheduleDays = [1, 2, 3, 4, 5, 6, 7];
        
        // Navigate back immediately - no SnackBar interference
        Navigator.of(context).pop();
        print('DEBUG: Navigator.pop() executed - should be back on home screen');
      }
    } catch (e) {
      print('DEBUG: Exception during habit creation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _pickResetDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _resetAnchor,
      firstDate: _resetAnchor.isBefore(DateTime(2020)) ? _resetAnchor : DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 366)),
      helpText: _selectedFrequency == ResetFrequency.weekly
          ? 'Pick a day: the habit resets on that weekday'
          : _selectedFrequency == ResetFrequency.monthly
              ? 'Pick a day: the habit resets on that day each month'
              : 'Pick the start date',
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
          if (_reminderDaysFollowSchedule) {
            _selectedDays = List.of(_scheduleDays);
          }
        });
      },
    );
  }

  Widget _buildDayChip(int dayOfWeek, String label) {
    final isSelected = _selectedDays.contains(dayOfWeek);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          // Reminder days chosen by hand stop following the schedule
          _reminderDaysFollowSchedule = false;
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