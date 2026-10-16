import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../domain/entities/habit.dart';
import '../domain/entities/habit_category.dart';
import '../domain/entities/habit_color.dart';
import '../domain/entities/reset_frequency.dart';
import '../domain/entities/reminder_settings.dart';
import '../domain/usecases/create_habit_usecase.dart';
import '../domain/usecases/update_habit_usecase.dart';
import '../presentation/providers/theme_provider.dart';
import '../presentation/providers/habit_provider.dart';
import '../presentation/widgets/category_icons.dart';
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
  HabitCategory _selectedCategory = HabitCategory.body;
  ResetFrequency _selectedFrequency = ResetFrequency.daily;
  // Weekly habits reset on this date's weekday, monthly on its day of month
  DateTime _resetAnchor = DateUtils.dateOnly(DateTime.now());
  
  // Reminder settings
  bool _reminderEnabled = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 9, minute: 0);
  List<int> _selectedDays = [1, 2, 3, 4, 5, 6, 7]; // All days by default
  String _customMessage = '';
  
  // Icon selection
  String? _selectedIcon;
  
  // Apple's Human Interface Guidelines: tap targets at least 44x44 pt
  static const double _swatchSize = 44;
  static const double _swatchSpacing = 12;
  static const double _chipSpacing = 8;

  // Available habit icons
  static const Map<String, IconData> habitIcons = {
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

  @override
  void initState() {
    super.initState();
    
    // If editing an existing habit, populate the form
    if (widget.editHabit != null) {
      final habit = widget.editHabit!;
      _nameController.text = habit.name;
      _targetController.text = habit.target.toString();
      _unitsController.text = habit.units;
      _selectedColor = habit.color;
      _selectedCategory = habit.category;
      _selectedFrequency = habit.resetFrequency;
      _resetAnchor = habit.resetAnchor;
      
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
  }

  @override
  void dispose() {
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
                
        return Scaffold(
      appBar: AppBar(
        title: Text(widget.editHabit != null ? 'Edit Habit' : 'Add New Habit'),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
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
                decoration: const InputDecoration(
                  labelText: 'Target Number',
                  hintText: 'e.g., 8, 30, 5',
                  border: OutlineInputBorder(),
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
                children: HabitCategory.values.map((category) {
                  final isSelected = _selectedCategory == category;
                  return FilterChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(category.icon, size: 16, color: category.defaultColor),
                        const SizedBox(width: 4),
                        Text(category.displayName),
                      ],
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = category;
                      });
                    },
                    backgroundColor: isSelected ? category.defaultColor.withOpacity(0.2) : null,
                  );
                }).toList(),
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
              Wrap(
                spacing: _swatchSpacing,
                runSpacing: _swatchSpacing,
                children: HabitColor.predefinedColors.map((color) {
                  final isSelected = _selectedColor == color;
                  return _buildSwatch(
                    key: Key('colorSwatch_${color.name}'),
                    semanticLabel: '${color.name} color',
                    isSelected: isSelected,
                    onTap: () => setState(() => _selectedColor = color),
                    fill: color.color,
                    borderColor: isSelected ? Theme.of(context).primaryColor : null,
                    borderWidth: 3,
                    child: isSelected
                        ? Icon(
                            Icons.check,
                            color: isDark ? IOSColors.black : IOSColors.white,
                            size: 22,
                          )
                        : null,
                  );
                }).toList(),
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
                  _buildSwatch(
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
                  ...habitIcons.entries.map((entry) {
                    final iconKey = entry.key;
                    final isSelected = _selectedIcon == iconKey;
                    return _buildSwatch(
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
              
              // Frequency Selection
              const Text(
                'Reset Frequency',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<ResetFrequency>(
                value: _selectedFrequency,
                // Fill the width so long hints/labels truncate instead of overflowing
                isExpanded: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'How often should this habit reset?',
                ),
                items: ResetFrequency.values.map((frequency) {
                  return DropdownMenuItem<ResetFrequency>(
                    value: frequency,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_getFrequencyIcon(frequency), size: 20),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(frequency.displayName, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (ResetFrequency? newFrequency) {
                  if (newFrequency != null) {
                    setState(() {
                      _selectedFrequency = newFrequency;
                    });
                  }
                },
              ),
              if (_selectedFrequency.describeResetDay(_resetAnchor) != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ListTile(
                    key: const Key('resetDayTile'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_repeat),
                    title: Text(_selectedFrequency.describeResetDay(_resetAnchor)!),
                    trailing: TextButton(
                      onPressed: _pickResetDay,
                      child: const Text('Change'),
                    ),
                    onTap: _pickResetDay,
                  ),
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
                    _buildDayChip(1, 'Mon'),
                    _buildDayChip(2, 'Tue'), 
                    _buildDayChip(3, 'Wed'),
                    _buildDayChip(4, 'Thu'),
                    _buildDayChip(5, 'Fri'),
                    _buildDayChip(6, 'Sat'),
                    _buildDayChip(7, 'Sun'),
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
                    _customMessage = value;
                  },
                ),
              ],
              
              const SizedBox(height: 32),
              
              // Submit Button
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitForm,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(widget.editHabit != null ? 'Update Habit' : 'Add Habit'),
              ),
            ],
          ),
        ),
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
        category: _selectedCategory,
        resetFrequency: _selectedFrequency,
        reminder: reminder,
        icon: _selectedIcon,
        resetAnchor: _resetAnchor,
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
          category: params.category,
          resetFrequency: params.resetFrequency,
          reminder: reminder,
          icon: _selectedIcon,
          resetAnchor: _resetAnchor,
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
        _selectedCategory = HabitCategory.body;
        _selectedFrequency = ResetFrequency.daily;
        
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

  /// A circular, 44pt selectable swatch with a VoiceOver label.
  Widget _buildSwatch({
    required Key key,
    required String semanticLabel,
    required bool isSelected,
    required VoidCallback onTap,
    required Color fill,
    required Color? borderColor,
    required double borderWidth,
    Widget? child,
  }) {
    return Semantics(
      key: key,
      label: semanticLabel,
      button: true,
      selected: isSelected,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: _swatchSize,
          height: _swatchSize,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: borderColor != null ? Border.all(color: borderColor, width: borderWidth) : null,
          ),
          child: child,
        ),
      ),
    );
  }

  Future<void> _pickResetDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _resetAnchor,
      firstDate: _resetAnchor.isBefore(DateTime(2020)) ? _resetAnchor : DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 366)),
      helpText: _selectedFrequency == ResetFrequency.weekly
          ? 'Pick a day: the habit resets on that weekday'
          : 'Pick a day: the habit resets on that day each month',
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
  
  Widget _buildDayChip(int dayOfWeek, String label) {
    final isSelected = _selectedDays.contains(dayOfWeek);
    return FilterChip(
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