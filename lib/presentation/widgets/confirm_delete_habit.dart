import 'package:flutter/material.dart';

/// Asks before deleting a habit and its history. Returns true to delete.
Future<bool> confirmDeleteHabit(BuildContext context, String habitName) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete Habit'),
      content: Text('Are you sure you want to delete "$habitName"?\n\nThis action cannot be undone.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const Key('confirmDeleteHabit'),
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return confirmed == true;
}
