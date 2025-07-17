import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../domain/entities/habit.dart';
import '../domain/entities/habit_category.dart';
import '../domain/entities/habit_color.dart';
import '../domain/entities/reset_frequency.dart';
import '../domain/usecases/create_habit_usecase.dart';
import '../domain/usecases/update_habit_usecase.dart';
import '../presentation/providers/theme_provider.dart';
import '../presentation/providers/habit_provider.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editHabit != null ? 'Edit Habit' : 'Add New Habit'),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: Padding(
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
                spacing: 8,
                children: HabitCategory.values.map((category) {
                  final isSelected = _selectedCategory == category;
                  return FilterChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(category.emoji),
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
                spacing: 8,
                children: HabitColor.predefinedColors.map((color) {
                  final isSelected = _selectedColor == color;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedColor = color;
                      });
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color.color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(
                                color: Theme.of(context).primaryColor,
                                width: 3,
                              )
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 20,
                            )
                          : null,
                    ),
                  );
                }).toList(),
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
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'How often should this habit reset?',
                ),
                items: ResetFrequency.values.map((frequency) {
                  return DropdownMenuItem<ResetFrequency>(
                    value: frequency,
                    child: Row(
                      children: [
                        Icon(_getFrequencyIcon(frequency), size: 20),
                        const SizedBox(width: 8),
                        Text(frequency.displayName),
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
              
              const SizedBox(height: 16),
              
              // Debug info panel
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('DEBUG INFO:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    Text('Submitting: $_isSubmitting', style: TextStyle(fontSize: 10)),
                    Text('Mounted: $mounted', style: TextStyle(fontSize: 10)),
                    Text('Form valid: ${_formKey.currentState?.validate() ?? false}', style: TextStyle(fontSize: 10)),
                    Text('Frequency: ${_selectedFrequency.displayName}', style: TextStyle(fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
      
      final params = CreateHabitParams(
        name: _nameController.text.trim(),
        target: int.parse(_targetController.text.trim()),
        units: _unitsController.text.trim(),
        color: _selectedColor,
        category: _selectedCategory,
        resetFrequency: _selectedFrequency,
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
}