import 'package:flutter/material.dart';
import 'adaptive.dart';

/// Asks before deleting a habit and its history. Returns true to delete.
Future<bool> confirmDeleteHabit(BuildContext context, String habitName) {
  return confirmAdaptive(
    context,
    title: 'Delete "$habitName"?',
    message: 'Its history and streak will be deleted too. This can\'t be undone.',
    confirmLabel: 'Delete',
    destructive: true,
    confirmKey: const Key('confirmDeleteHabit'),
  );
}
