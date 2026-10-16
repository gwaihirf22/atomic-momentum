import 'package:flutter/material.dart';

/// Asks whether to throw away unsaved edits. Returns true to discard.
Future<bool> confirmDiscardChanges(BuildContext context) async {
  final discard = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Discard changes?'),
      content: const Text('Your unsaved changes will be lost.'),
      actions: [
        TextButton(
          key: const Key('keepEditing'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Keep Editing'),
        ),
        TextButton(
          key: const Key('discardChanges'),
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Discard'),
        ),
      ],
    ),
  );
  return discard == true;
}

/// While [hasChanges], leaving the route (back button, back gesture, tapping
/// outside a sheet) first asks whether to discard them. Saving should leave
/// with Navigator.pop, which isn't intercepted.
class UnsavedChangesGuard extends StatelessWidget {
  final bool hasChanges;
  final Widget child;

  const UnsavedChangesGuard({Key? key, required this.hasChanges, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: !hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await confirmDiscardChanges(context) && context.mounted) {
          Navigator.of(context).pop(result);
        }
      },
      child: child,
    );
  }
}
