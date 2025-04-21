import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../services/habit_service.dart';

class AddHabitScreen extends StatefulWidget {
  @override
  _AddHabitScreenState createState() => _AddHabitScreenState();
}

class _AddHabitScreenState extends State<AddHabitScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _targetController = TextEditingController();
  
  final HabitService _habitService = HabitService();
  bool _isSubmitting = false;

  // Predefined colors for habit tracking
  final List<Color> _availableColors = [
    Colors.purple, 
    Colors.blue, 
    Colors.teal, 
    Colors.orange, 
    Colors.red,
  ];
  
  // Default selected color
  Color _selectedColor = Colors.purple;

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isSubmitting = true;
      });

      try {
        // Create new habit
        final name = _nameController.text.trim();
        final target = int.parse(_targetController.text.trim());
        
        // Add habit and save to storage
        await _habitService.addHabit(Habit(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: name,
          target: target,
          progress: 0,
          color: _selectedColor,
        ));

        // Return to previous screen
        Navigator.pop(context);
      } catch (e) {
        // Show error if something went wrong
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving habit: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        // Update UI state if we're still mounted
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Dismiss keyboard when tapping outside of text fields
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: Text('Add New Habit'),
          centerTitle: true,
        ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeaderIcon(),
                SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  style: TextStyle(fontSize: 16),
                  decoration: InputDecoration(
                    labelText: 'Habit Name',
                    labelStyle: TextStyle(fontSize: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    prefixIcon: Icon(Icons.edit),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a habit name';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _targetController,
                  style: TextStyle(fontSize: 16),
                  decoration: InputDecoration(
                    labelText: 'Goal Number',
                    labelStyle: TextStyle(fontSize: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    prefixIcon: Icon(Icons.track_changes),
                    hintText: 'How many times per week?',
                    hintStyle: TextStyle(fontSize: 16),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a target number';
                    }
                    
                    final number = int.tryParse(value);
                    if (number == null) {
                      return 'Please enter a valid number';
                    }
                    
                    if (number <= 0) {
                      return 'Target must be greater than zero';
                    }
                    
                    if (number > 100) {
                      return 'Target must be 100 or less';
                    }
                    
                    return null;
                  },
                ),
                SizedBox(height: 24),
                _buildColorPicker(),
                SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitForm,
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: _isSubmitting
                        ? CircularProgressIndicator(color: Colors.white)
                        : Text(
                            'Create Habit',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ));
  }

  Widget _buildColorPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Habit Color',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 12),
        Container(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _availableColors.length,
            itemBuilder: (context, index) {
              final color = _availableColors[index];
              final isSelected = _selectedColor == color;
              
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedColor = color;
                  });
                },
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  margin: EdgeInsets.only(right: 16),
                  width: isSelected ? 65 : 55,
                  height: isSelected ? 65 : 55,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.black : Colors.grey.withOpacity(0.3),
                      width: isSelected ? 3 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected ? color.withOpacity(0.6) : Colors.transparent,
                        blurRadius: isSelected ? 8 : 0,
                        spreadRadius: isSelected ? 2 : 0,
                      )
                    ],
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 28,
                        )
                      : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderIcon() {
    return Column(
      children: [
        Icon(
          Icons.add_task,
          size: 80,
          color: _selectedColor,
        ),
        SizedBox(height: 16),
        Text(
          'Add a New Habit',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Track your progress towards consistency',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
      ],
    );
  }
}
