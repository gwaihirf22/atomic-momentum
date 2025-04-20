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

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isSubmitting = true;
      });

      // Create new habit
      final name = _nameController.text.trim();
      final target = int.parse(_targetController.text.trim());
      
      _habitService.addHabit(Habit(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        target: target,
        progress: 0,
      ));

      setState(() {
        _isSubmitting = false;
      });

      // Return to previous screen
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  decoration: InputDecoration(
                    labelText: 'Habit Name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
                  decoration: InputDecoration(
                    labelText: 'Daily Target',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: Icon(Icons.track_changes),
                    hintText: 'How many times per day?',
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
    );
  }

  Widget _buildHeaderIcon() {
    return Column(
      children: [
        Icon(
          Icons.add_task,
          size: 80,
          color: Theme.of(context).primaryColor,
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
