import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../domain/entities/habit_category.dart';
import '../domain/entities/habit_color.dart';
import '../domain/usecases/create_habit_usecase.dart';
import '../presentation/providers/theme_provider.dart';
import '../presentation/providers/habit_provider.dart';

class AddHabitScreen extends StatefulWidget {
  const AddHabitScreen({Key? key}) : super(key: key);

  @override
  _AddHabitScreenState createState() => _AddHabitScreenState();
}

class _AddHabitScreenState extends State<AddHabitScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _targetController = TextEditingController();
  
  bool _isSubmitting = false;
  
  // Selected values
  HabitColor _selectedColor = HabitColor.blue;
  HabitCategory _selectedCategory = HabitCategory.body;

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Habit'),
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
                  labelText: 'Target',
                  hintText: 'e.g., 8 glasses, 30 minutes',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a target';
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
                    : const Text('Add Habit'),
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
      
      final params = CreateHabitParams(
        name: _nameController.text.trim(),
        target: int.parse(_targetController.text.trim()),
        color: _selectedColor,
        category: _selectedCategory,
      );

      final success = await habitProvider.createHabit(params);

      if (success && mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_nameController.text.trim()} added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Go back to previous screen
        Navigator.of(context).pop();
      } else if (mounted) {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(habitProvider.error ?? 'Failed to create habit'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _submitForm,
            ),
          ),
        );
      }
    } catch (e) {
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
}