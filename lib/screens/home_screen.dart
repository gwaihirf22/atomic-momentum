import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../services/habit_service.dart';
import 'add_habit_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final HabitService _habitService = HabitService();
  List<Habit> habits = [];

  @override
  void initState() {
    super.initState();
    _loadHabits();
  }

  void _loadHabits() {
    setState(() {
      habits = _habitService.getHabits();
    });
  }

  void _updateHabitProgress(Habit habit, int newProgress) {
    if (newProgress >= 0 && newProgress <= habit.target) {
      setState(() {
        _habitService.updateHabitProgress(habit.id, newProgress);
        _loadHabits();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Momentum'),
        centerTitle: true,
      ),
      body: habits.isEmpty 
          ? _buildEmptyState() 
          : _buildHabitList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddHabitScreen(),
            ),
          ).then((_) => _loadHabits()); // Refresh habits when returning from add screen
        },
        child: Icon(Icons.add),
        tooltip: 'Add a new habit',
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.track_changes,
            size: 80,
            color: Theme.of(context).primaryColor.withOpacity(0.5),
          ),
          SizedBox(height: 16),
          Text(
            'No habits yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Tap the + button to add your first habit',
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHabitList() {
    return ListView.builder(
      itemCount: habits.length,
      padding: EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final habit = habits[index];
        return Card(
          margin: EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        habit.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      '${habit.progress}/${habit.target}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: habit.color,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                LinearProgressIndicator(
                  value: habit.progress / habit.target,
                  minHeight: 10,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(habit.color),
                  borderRadius: BorderRadius.circular(5),
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: Icon(Icons.remove_circle_outline),
                      onPressed: habit.progress > 0
                          ? () => _updateHabitProgress(habit, habit.progress - 1)
                          : null,
                      color: habit.color,
                    ),
                    IconButton(
                      icon: Icon(Icons.add_circle_outline),
                      onPressed: habit.progress < habit.target
                          ? () => _updateHabitProgress(habit, habit.progress + 1)
                          : null,
                      color: habit.color,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
